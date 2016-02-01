package C4::OPLIB::CPUIntegration;

use Modern::Perl;

use C4::Accounts;
use C4::Branch;
use C4::Context;
use C4::Log;

use Data::Dumper qw(Dumper);
use Digest::SHA qw(sha256_hex);
use Encode;
use Net::SSL;
use YAML::XS;

use Koha::Borrower;
use Koha::Borrowers;
use Koha::PaymentsTransaction;
use Koha::PaymentsTransactions;

use Koha::Exception::NoSystemPreference;

use bignum;

=head1 FUNCTIONS

=head2 InitializePayment

  &InitializePayment($args);

Initializes the accountlines that will be sent to CPU.

Returns the payment HASH.

=cut

sub InitializePayment {
    my ($args) = shift;

    my $dbh        = C4::Context->dbh;
    my $borrowernumber = $args->{borrowernumber};
    my @selected = @{ $args->{selected} };

    # Hash containing CPU format of payment
    my $payment;
    $payment->{Office} = $args->{office};
    $payment->{Products} = [];

    @selected = sort { $a <=> $b } @selected if @selected > 1;

    my $total_price = 0;
    my $money_left = _convert_to_cents($args->{total_paid});

    my $use_selected = (@selected > 0) ? "AND accountno IN (?".+(",?") x (@selected-1).")" : "";
    my $sql = "SELECT * FROM accountlines WHERE borrowernumber=? AND (amountoutstanding<>0) ".$use_selected." ORDER BY date";
    my $sth = $dbh->prepare($sql);

    $sth->execute($borrowernumber, @selected);

    # Create a new transaction
    my $transaction = Koha::PaymentsTransaction->new()->set({
            borrowernumber          => $borrowernumber,
            status                  => "unsent",
            description             => $args->{payment_note} || '',
    })->store();

    while ( (my $accdata = $sth->fetchrow_hashref) and $money_left > 0) {
        my $product;

        $product->{Code} = $accdata->{'accounttype'};
        $product->{Amount} = 1;
        $product->{Description} = $accdata->{'description'};

        if ( _convert_to_cents($accdata->{'amountoutstanding'}) >= $money_left ) {
            $product->{Price} = $money_left;
            $money_left = 0;
        } else {
            $product->{Price} = _convert_to_cents($accdata->{'amountoutstanding'});
            $money_left -= _convert_to_cents($accdata->{'amountoutstanding'});
        }
        push $payment->{Products}, $product;
        $total_price += $product->{Price};

        $transaction->AddRelatedAccountline($accdata->{'accountlines_id'}, $product->{Price});
    }

    $transaction->set({ price_in_cents => $total_price })->store();

    my $borrower = Koha::Borrowers->cast($transaction->borrowernumber);

    my $description = $borrower->surname . ", " . $borrower->firstname . " (".$borrower->cardnumber.")";

    $payment->{ApiVersion}  = "2.0";
    $payment->{Source}      = C4::Context->config('pos')->{'CPU'}->{'source'};
    $payment->{Id}          = $transaction->transaction_id;
    $payment->{Mode}        = C4::Context->config('pos')->{'CPU'}->{'mode'};
    $payment->{Description} = $description;
    $payment->{Products} = AccountTypesToItemNumbers($transaction->GetProducts(), C4::Branch::mybranch());

    my $notificationAddress = C4::Context->config('pos')->{'CPU'}->{'notificationAddress'};
    my $transactionNumber = $transaction->transaction_id;
    $notificationAddress =~ s/{invoicenumber}/$transactionNumber/g;

    $payment->{NotificationAddress} = $notificationAddress; # url for report
    
    $payment = _validate_cpu_hash($payment); # Remove semicolons
    $payment->{Hash}        = CalculatePaymentHash($payment);

    $payment = _validate_cpu_hash($payment); # Convert strings to int
    $payment->{"send_payment"} = "POST";

    return $payment;
}

=head2 SendPayment

  SendPayment($payment);

Sends a payment to CPU. $payment is a HASH that needs to be in the CPU format with
SHA-256 hash calculated correctly.

Returns JSON-encoded response from CPU. See the CPU document for response protocol.

=cut

sub SendPayment {
    my $content = shift;
    my $response;

    $response = eval {
        my $payment = $content;

        delete $payment->{send_payment} if $payment->{send_payment};

        # Convert strings to integer for JSON
        $payment = _validate_cpu_hash($payment);

        # Construct JSON object
        $content = JSON->new->utf8->canonical(1)->encode($payment);

        my $transaction = Koha::PaymentsTransactions->find($payment->{Id});

        if (C4::Context->config('pos')->{'CPU'}->{'ssl_cert'}) {
            # Define SSL certificate
            $ENV{HTTPS_CERT_FILE} = C4::Context->config('pos')->{'CPU'}->{'ssl_cert'};
            $ENV{HTTPS_KEY_FILE}  = C4::Context->config('pos')->{'CPU'}->{'ssl_key'};
            $ENV{HTTPS_CA_FILE} = C4::Context->config('pos')->{'CPU'}->{'ssl_ca_file'};
        }

        my $ua = LWP::UserAgent->new;

        if (C4::Context->config('pos')->{'CPU'}->{'ssl_cert'}) {
            $ua->ssl_opts({
                SSL_use_cert    => 1,
            });
        }

        $ua->timeout(500);

        my $req = HTTP::Request->new(POST => C4::Context->config('pos')->{'CPU'}->{'url'});
        $req->header('content-type' => 'application/json');
        $req->content($content);

        $transaction->set({ status => "pending" })->store();

        my $request = $ua->request($req);

        # There is an issue where the call above fails for unknown reasons, but REST API got
        # confirmation of successful payment. We need to be able to recognize payments
        # that have been completed during $ua->request($req) by REST API and not set them to
        # "cancelled" status even if $ua->request($req) returns some HTTP error code.
        # At this point, payment should still be "pending". Refresh payment status.

        $transaction = Koha::PaymentsTransactions->find($payment->{Id});
        my $payment_already_paid = 1 if $transaction->status eq "paid"; # Already paid via REST API!
        return JSON->new->utf8->canonical(1)->encode({ Status => '1' }) if $payment_already_paid;

        if ($request->{_rc} != 200) {
            # Did not get HTTP 200, some error happened!
            $transaction->set({ status => "cancelled", description => $request->{_content} })->store();
            return JSON->new->utf8->canonical(1)->encode({ error => $request->{_content}, Status => '89' });
        }

        my $response = JSON->new->utf8->canonical(1)->decode($request->{_content});

        # Calculate response checksum and return error if they do not match
        my $hash = CalculateResponseHash($response);

        if ($hash ne $response->{Hash}) {
            $transaction->set({ status => "cancelled", description => "Invalid hash" })->store();
            return JSON->new->utf8->canonical(1)->encode({ error => "Invalid hash", Status => $response->{Status} });
        }

        return JSON->new->utf8->canonical(1)->encode($response);
    };

    if ($@) {
        my $transaction = Koha::PaymentsTransactions->find($content->{Id});
        my $payment_already_paid = 1 if $transaction->status eq "paid"; # Already paid via REST API!
        return JSON->new->utf8->canonical(1)->encode({ Status => '1' }) if $payment_already_paid;
        $transaction->set({ status => "cancelled", description => $@ })->store();
        return JSON->new->utf8->canonical(1)->encode({ error => "Error: " . $@, Status => '88' });
    }

    return $response;
}

=head2 HandleResponseStatus

  HandleResponseStatus($code, $transaction)

Sets the correct transaction status according to the status code in CPU response.

Returns a Koha::PaymentsTransaction object

=cut
sub HandleResponseStatus {
    my ($code, $transaction) = @_;

    my $status = getResponseString($code);

    $transaction->set($status)->store(); # set the status

    return $transaction;
}

=head2 GetResponseString

  GetResponseString($statuscode)

  Converts CPU Status code into string recognized by payments_transactions.status
  e.g. paid, cancelled, pending

Returns status as string

=cut
sub GetResponseString {
    my ($code) = @_;

    my $status;
    $status->{status} = "cancelled"; # default status

    if ($code == 0) {
        # Payment was cancelled
    }
    elsif ($code == 1) {
        # Payment was successful
        $status->{status} = "paid";
    }
    elsif ($code == 2) {
        # Payment is pending
        $status->{status} = "pending";
    }
    elsif ($code == 97) {
        # Id was duplicate (duplicate transaction id - different hash)
        $status->{description} = "ERROR 97: Duplicate id";
    }
    elsif ($code == 98) {
        # System error
        $status->{description} = "ERROR 98: System error";
    }
    elsif ($code == 99) {
        # Invalid invoice
        $status->{description} = "ERROR 99: Invalid invoice";
    }
    else {
        $status->{description} = "Unknown status";
    }
    
    return $status;
}

=head2 hasBranchEnabledIntegration

  hasBranchEnabledIntegration($branch);

  Checks if the $branch has enabled POS integration. Integration is enabled
  when the systempreference "cpuitemnumber" YAML config has mapping of
  Koha-itemtypes to CPU-itemnumbers for $branch.

Returns 1 if yes, otherwise 0.

=cut
sub hasBranchEnabledIntegration {
    my ($branch) = @_;
    
    # Load YAML conf from syspref cpuitemnumbers
    my $pref = C4::Context->preference("cpuitemnumbers");
    return 0 unless $pref;
    my $config = YAML::XS::Load(
                        Encode::encode(
                            'UTF-8',
                            $pref,
                            Encode::FB_CROAK
                        ));

    return 0 unless $config->{$branch};
    return 1;
}

=head2 AccountTypesToItemNumbers

  AccountTypesToItemNumbers($products, $branch);

Maps Koha-itemtypes (accountlines.accounttype) to CPU itemnumbers.

This is defined in system preference "cpuitemnumbers".

Products is an array of Product (HASH) that are in the format of CPU-document.

Returns an ARRAY of products (HASH).

=cut
sub AccountTypesToItemNumbers {
    my ($products, $branch) = @_;

    # Load YAML conf from syspref cpuitemnumbers
    my $pref = C4::Context->preference("cpuitemnumbers");
    Koha::Exception::NoSystemPreference->throw( error => "YAML configuration in system preference 'cpuitemnumbers' is not defined! Cannot assign item numbers for accounttypes." ) unless $pref;
    my $config = YAML::XS::Load(
                        Encode::encode(
                            'UTF-8',
                            $pref,
                            Encode::FB_CROAK
                        ));

    Koha::Exception::NoSystemPreference->throw( error => "No item number configuration for branch '".$branch."'. Configure system preference 'cpuitemnumbers'") unless $config->{$branch};

    my $modified_products;

    for my $product (@$products){
        my $mapped_product = $product;

        # If accounttype is mapped to an item number
        if ($config->{$branch}->{$product->{Code}}) {
            $mapped_product->{Code} = $config->{$branch}->{$product->{Code}}
        } else {
            # Else, try to use accounttype "Default"
            Koha::Exception::NoSystemPreference->throw( error => "Could not assign item number to accounttype '".$product->{Code}."'. Configure system preference 'cpuitemnumbers' with parameters 'Default'.") unless $config->{$branch}->{'Default'};

            $mapped_product->{Code} = $config->{$branch}->{'Default'};
        }

        push @$modified_products, $mapped_product;
    }

    return $modified_products;
}


=head2 CalculatePaymentHash

  CalculatePaymentHash($response);

Calculates SHA-256 hash from our payment hash. Returns the SHA-256 string.

=cut

sub CalculatePaymentHash {
    my $invoice = shift;
    my $data;

    foreach my $param (sort keys $invoice){
        next if $param eq "Hash";
        my $value = $invoice->{$param};

        if (ref($invoice->{$param}) eq 'ARRAY') {
            my $product_hash = $value;
            $value = "";
            foreach my $product (values $product_hash){
                foreach my $product_data (sort keys $product){
                    $value .= $product->{$product_data} . "&";
                }
            }
            $value =~ s/&$//g
        }

        $data .= $value . "&";
    }

    $data .= C4::Context->config('pos')->{'CPU'}->{'secretKey'};
    $data = Encode::encode_utf8($data);
    return Digest::SHA::sha256_hex($data);
}

=head2 CalculateResponseHash

  CalculateResponseHash($response);

Calculates SHA-256 hash from CPU's response. Returns the SHA-256 string.

=cut

sub CalculateResponseHash {
    my $resp = shift;
    my $data = "";

    $data .= $resp->{Source} if defined $resp->{Source};
    $data .= "&" . $resp->{Id} if defined $resp->{Id};
    $data .= "&" . $resp->{Status} if defined $resp->{Status};
    $data .= "&" . $resp->{Reference} if defined $resp->{Reference};
    $data .= "&" . C4::Context->config('pos')->{'CPU'}->{'secretKey'};

    $data =~ s/^&//g;

    $data = Digest::SHA::sha256_hex($data);
    return $data;
}

sub _validate_cpu_hash {
    my $invoice = shift;

    # CPU does not like a semicolon. Go through the fields and make sure
    # none of the fields contain ';' character (from CPU documentation)
    foreach my $field (keys $invoice){
        $invoice->{$field} =~ s/;//g; # Remove semicolon
    }

    $invoice->{Mode} = int($invoice->{Mode});
    foreach my $product (@{ $invoice->{Products} }){
        foreach my $product_field (keys $product){
            $product->{$product_field} =~ s/;//g; # Remove semicolon
        }
        $product->{Amount} = int($product->{Amount}) if $product->{Amount};
        $product->{Price} = int($product->{Price}) if $product->{Price};
    }

    return $invoice;
}

sub _convert_to_cents {
    my ($price) = @_;

    return int($price*100); # transform into cents
}

sub _convert_to_euros {
    my ($price) = @_;

    return $price/100;
}

1;
