package C4::OPLIB::CPUIntegration;

use Modern::Perl;

use C4::Accounts;
use C4::Branch;
use C4::Context;
use C4::Log;

use Data::Dumper qw(Dumper);
use Digest::SHA qw(sha256_hex);
use Encode;
use IO::Socket::SSL;
use YAML::XS;

use Koha::Borrower;
use Koha::Borrowers;
use Koha::Items;
use Koha::PaymentsTransaction;
use Koha::PaymentsTransactions;

use Koha::Exception::NoSystemPreference;

use bignum;

=head1 FUNCTIONS

=head2 InitializePayment

  &InitializePayment(
        transaction => Koha::PaymentsTransaction-object,
        office      => 15,
  );

Initializes the accountlines that will be sent to CPU.

Returns the payment HASH.

=cut

sub InitializePayment {
    my ($args) = shift;

    my $transaction = $args->{transaction};

    my $mode = (not $transaction->is_self_payment) ? 'pos' : 'online_payments';

    # Hash containing CPU format of payment
    my $payment;
    $payment->{Office} = $args->{office} if $mode eq 'pos';

    my $borrower = Koha::Borrowers->cast($transaction->borrowernumber);

    my $description = $borrower->surname . ", " . $borrower->firstname . " (".$borrower->cardnumber.")";

    $payment->{ApiVersion}  = "2.0";
    $payment->{Source}      = C4::Context->config($mode)->{'CPU'}->{'source'};
    $payment->{Id}          = $transaction->transaction_id;
    $payment->{Mode}        = C4::Context->config($mode)->{'CPU'}->{'mode'};
    $payment->{Description} = $description;
    $payment->{Products} =  AccountTypesToItemNumbers(
                                _convert_to_cpu_products(
                                    $transaction->GetProducts()),
                                    C4::Branch::mybranch(),
                                    ($mode eq "online_payments") ? 1 : 0
                            );

    # Online payment specific parameters
    if ($mode eq 'online_payments') {
        #delete $payment->{Office}; # not needed in online payments
        $payment->{Email} = $borrower->email;
        $payment->{FirstName} = $borrower->firstname;
        $payment->{LastName} = $borrower->surname;
        $payment->{ReturnAddress} = C4::Context->config($mode)->{'CPU'}->{'returnAddress'};
    }

    my $notificationAddress = C4::Context->config($mode)->{'CPU'}->{'notificationAddress'};
    my $transactionNumber = $transaction->transaction_id;
    $notificationAddress =~ s/{invoicenumber}/$transactionNumber/g;

    $payment->{NotificationAddress} = $notificationAddress; # url for report

    $payment = _validate_cpu_hash($payment); # Remove semicolons
    $payment->{Hash}        = CalculatePaymentHash($payment);

    $payment = _validate_cpu_hash($payment); # Convert strings to int
    $payment->{"send_payment"} = "POST" if $mode eq 'pos';

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
        my $mode = (not $transaction->is_self_payment) ? 'pos' : 'online_payments';

        my $ua = LWP::UserAgent->new;

        if (C4::Context->config($mode)->{'CPU'}->{'ssl_cert'}) {
            $ua->ssl_opts(
                SSL_use_cert    => 1,
                SSL_cert_file   => C4::Context->config($mode)->{'CPU'}->{'ssl_cert'},
                SSL_key_file    => C4::Context->config($mode)->{'CPU'}->{'ssl_key'},
                SSL_ca_file     => C4::Context->config($mode)->{'CPU'}->{'ssl_ca_file'},
                verify_hostname => 1,
            );
        }

        $ua->timeout(500);

        my $req = HTTP::Request->new(POST => C4::Context->config($mode)->{'CPU'}->{'url'});
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

        # Check if CPU returns us a server error
        my $response_str = GetResponseString($response->{Status});
        if (defined $response_str->{description}) {
            $transaction->set({ status => "cancelled", description => $response_str->{description} })->store();
            return JSON->new->utf8->canonical(1)->encode({ error => $response_str->{description}, Status => $response->{Status} });
        }

        return JSON->new->utf8->canonical(1)->encode($response);
    };

    if ($@) {
        my $error = $@;
        $content = JSON->new->utf8->canonical(1)->decode($content) unless ref($content) eq 'HASH';
        my $transaction = Koha::PaymentsTransactions->find($content->{Id});
        my $payment_already_paid = 1 if $transaction->status eq "paid"; # Already paid via REST API!
        return JSON->new->utf8->canonical(1)->encode({ Status => '1' }) if $payment_already_paid;
        $transaction->set({ status => "cancelled", description => $error })->store();
        return JSON->new->utf8->canonical(1)->encode({ error => "Error: " . $error, Status => '88' });
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

  AccountTypesToItemNumbers($products, $branch, $is_online_payment);

Maps Koha-itemtypes (accountlines.accounttype) to CPU itemnumbers.

This is defined in system preference "cpuitemnumbers" for POS integration,
and "cpuitemnumbers_online_shop" for online (self) payments.

If $is_online_payment is true, we will map itemnumbers according to the
"cpuitemnumbers_online_shop" (Online payments). Otherwise, we will map
the itemnumbers for each branch defined in "cpuitemnumbers" syspref (POS integration).

Products is an array of Product (HASH) that are in the format of CPU-document.
Additionally, a product can have _itemnumber to define product code by item's home branch.

Returns an ARRAY of products (HASH).

=cut
sub AccountTypesToItemNumbers {
    my ($products, $branch, $is_online_payment) = @_;

    my ($pref, $config);

    if ($is_online_payment) {
        # Online payments:
        # Load YAML conf from syspref
        $pref = C4::Context->preference("cpuitemnumbers_online_shop");
        Koha::Exception::NoSystemPreference->throw( error => "YAML configuration in system preference 'cpuitemnumbers_online_shop' is not defined! Cannot assign item numbers for accounttypes." ) unless $pref;
        $config = YAML::XS::Load(
                            Encode::encode(
                                'UTF-8',
                                $pref,
                                Encode::FB_CROAK
                            ));
        $branch = "Default" unless ($config->{$branch});
    } else {
        # POS integration:
        # Load YAML conf from syspref cpuitemnumbers
        $pref = C4::Context->preference("cpuitemnumbers");
        Koha::Exception::NoSystemPreference->throw( error => "YAML configuration in system preference 'cpuitemnumbers' is not defined! Cannot assign item numbers for accounttypes." ) unless $pref;
        $config = YAML::XS::Load(
                            Encode::encode(
                                'UTF-8',
                                $pref,
                                Encode::FB_CROAK
                            ));

        Koha::Exception::NoSystemPreference->throw( error => "No item number configuration for branch '".$branch."'. Configure system preference 'cpuitemnumbers'") unless $config->{$branch};
    }

    my $modified_products;

    for my $product (@$products){
        my $mapped_product = $product;
        my $tmp_branch = $branch;
        # Use the home branch of item instead of home branch of Patron in online payments
        if ($is_online_payment && defined $product->{'_itemnumber'}){ # In order to enable same feature for POS integration, simply remove "$is_online_payment"
            my $item = Koha::Items->find($product->{'_itemnumber'});
            if ($item && $item->homebranch && exists $config->{$item->homebranch}){
                $tmp_branch = $item->homebranch;
            }
            delete $product->{'_itemnumber'}; # delete itemnumber - it is NOT a parameter that CPU wants
        }
        # If accounttype is mapped to an item number
        if ($config->{$tmp_branch}->{$product->{Code}}) {
            $mapped_product->{Code} = $config->{$tmp_branch}->{$product->{Code}}
        } else {
            # Else, try to use accounttype "Default"
            Koha::Exception::NoSystemPreference->throw( error => "Could not assign item number to accounttype '".$product->{Code}."'. Configure system preference 'cpuitemnumbers' or 'cpuitemnumbers_online_shop' with parameters 'Default'.") unless $config->{$tmp_branch}->{'Default'};

            $mapped_product->{Code} = $config->{$tmp_branch}->{'Default'};
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

    # FIXME:
    # CPU had incorrect algorithm for calculating payment hash in POS integration. A fix from their side will be
    # done. After their fix, we can simply use _calc_payment_hash() for both POS integration and online payments.
    return (defined $invoice->{ReturnAddress}) ? _calc_payment_hash($invoice) : _calc_pos_payment_hash($invoice);
}

sub _calc_pos_payment_hash {
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

sub _calc_payment_hash {
    my $invoice = shift;
    my $data;

    my $mode = (defined $invoice->{ReturnAddress}) ? "online_payments" : "pos";

    $data .= (defined $invoice->{ApiVersion}) ? "&" . $invoice->{ApiVersion} : "&"
        if exists $invoice->{ApiVersion};
    $data .= (defined $invoice->{Source}) ? "&" . $invoice->{Source} : "&"
        if exists $invoice->{Source};
    $data .= (defined $invoice->{Id}) ? "&" . $invoice->{Id} : "&"
        if exists $invoice->{Id};
    $data .= (defined $invoice->{Mode}) ? "&" . $invoice->{Mode} : "&"
        if exists $invoice->{Mode};
    $data .= (defined $invoice->{Office}) ? "&" . $invoice->{Office} : "&"
        if exists $invoice->{Office};
    $data .= (defined $invoice->{Action}) ? "&" . $invoice->{Action} : "&"
        if exists $invoice->{Action};
    $data .= (defined $invoice->{Description}) ? "&" . $invoice->{Description} : "&"
        if exists $invoice->{Description};
    foreach my $product (@{ $invoice->{Products} }) {
        $data .= (defined $product->{Code}) ? "&" . $product->{Code} : "&"
        if exists $product->{Code};
        $data .= (defined $product->{Amount}) ? "&" . $product->{Amount} : "&"
        if exists $product->{Amount};
        $data .= (defined $product->{Price}) ? "&" . $product->{Price} : "&"
        if exists $product->{Price};
        $data .= (defined $product->{Description}) ? "&" . $product->{Description} : "&"
        if exists $product->{Description};
        $data .= (defined $product->{Taxcode}) ? "&" . $product->{Taxcode} : "&"
        if exists $product->{Taxcode};
    }
    $data .= (defined $invoice->{Email}) ? "&" . $invoice->{Email} : "&"
        if exists $invoice->{Email};
        $data .= (defined $invoice->{FirstName}) ? "&" . $invoice->{FirstName} : "&"
        if exists $invoice->{FirstName};
        $data .= (defined $invoice->{LastName}) ? "&" . $invoice->{LastName} : "&"
        if exists $invoice->{LastName};
        $data .= (defined $invoice->{ReturnAddress}) ? "&" . $invoice->{ReturnAddress} : "&"
        if exists $invoice->{ReturnAddress};
        $data .= (defined $invoice->{NotificationAddress}) ? "&" . $invoice->{NotificationAddress} : "&"
        if exists $invoice->{NotificationAddress};

    $data =~ s/^&//g; # Remove first &
    $data .= "&" . C4::Context->config($mode)->{'CPU'}->{'secretKey'};
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

    my $transaction = Koha::PaymentsTransactions->find($resp->{Id});
    return if not $transaction;
    my $mode = (not $transaction->is_self_payment) ? 'pos' : 'online_payments';

    $data .= $resp->{Source} if defined $resp->{Source};
    $data .= "&" . $resp->{Id} if defined $resp->{Id};
    $data .= "&" . $resp->{Status} if defined $resp->{Status};
    $data .= "&" if exists $resp->{Reference};
    $data .= $resp->{Reference} if defined $resp->{Reference};
    $data .= "&" . $resp->{PaymentAddress} if defined $resp->{PaymentAddress};
    $data .= "&" . C4::Context->config($mode)->{'CPU'}->{'secretKey'};

    $data =~ s/^&//g;

    $data = Digest::SHA::sha256_hex($data);
    return $data;
}

=head2 isOnlinePaymentsEnabled

  isOnlinePaymentsEnabled($branch);

Checks if CPU Online Payments is enabled for $branch

If yes, returns accounttype to itemnumber mapping.

=cut

sub isOnlinePaymentsEnabled {
    my ($class, $branch) = @_;

    my $pref = C4::Context->preference("cpuitemnumbers_online_shop");

    if ($pref) {
        my $conf = eval {
            my $config = YAML::XS::Load(
                                Encode::encode(
                                    'UTF-8',
                                    $pref,
                                    Encode::FB_CROAK
                                ));
            return $config->{$branch} if $config->{$branch};
            return $config->{'Default'} if $config->{'Default'};
        };
        return $conf;
    }
}

sub _convert_to_cpu_products {
    my $products = shift;
    my $CPU_products;

    foreach my $product (@$products){
        my $tmp;

        #{
        #    no bignum;
        #    $tmp->{Amount} = 1;
        #}
        $tmp->{Price} = $product->{price};
        $tmp->{Description} = $product->{description};
        $tmp->{Code} = $product->{accounttype};
        $tmp->{_itemnumber} = $product->{itemnumber} if $product->{itemnumber};

        push @$CPU_products, $tmp;
    }

    return $CPU_products;
}

sub _validate_cpu_hash {
    my $invoice = shift;

    # CPU does not like a semicolon. Go through the fields and make sure
    # none of the fields contain ';' character (from CPU documentation)
    # Also it seems that fields should be trim()med or they could cause problems
    # in SHA2 hash calculation at payment server
    foreach my $field (keys $invoice){
        $invoice->{$field} =~ s/;//g if defined $invoice->{$field}; # Remove semicolon
        $invoice->{$field} =~ s/^\s+|\s+$//g if defined $invoice->{$field}; # Trim both ends
        my $tmp_field = $invoice->{$field};
        $tmp_field = substr($invoice->{$field}, 0, 99) if (ref($invoice->{$field}) ne "ARRAY") and ($field ne "ReturnAddress") and ($field ne "NotificationAddress");
        $tmp_field =~ s/^\s+|\s+$//g if defined $tmp_field; # Trim again, because after substr there can be again whitelines around left & right
        $invoice->{$field} = $tmp_field;
    }

    $invoice->{Mode} = int($invoice->{Mode});
    foreach my $product (@{ $invoice->{Products} }){
        foreach my $product_field (keys $product){
            $product->{$product_field} =~ s/;//g if defined $invoice->{$product_field}; # Remove semicolon
            $product->{$product_field} =~ s/'//g if defined $invoice->{$product_field}; # Remove '
            $product->{$product_field} =~ s/^\s+|\s+$//g if defined $invoice->{$product_field}; # Trim both ends
            $product->{$product_field} = substr($product->{$product_field}, 0, 99);
            $product->{$product_field} =~ s/^\s+|\s+$//g if defined $invoice->{$product_field}; # Trim again
        }
        $product->{Description} = "-" if $product->{'Description'} eq "";
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
