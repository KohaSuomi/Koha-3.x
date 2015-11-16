=head IN THIS FILE                                                                                                              
This module extends the SMS::Send::Driver interface                                                                             
to implement a driver compatible with the Labyrintti SMS Gateway HTTP interface.                                                
     
Module parameters are sanitated against injection attacks.

Labyrintti responds:

    - on success:
    
    format:  phone-number OK message-count description
    example: +358401234567 OK 1 message accepted for sending

    - on failure:
 
    format:  phone-number ERROR error-code message-count description
    example: 12345 ERROR 2 1 message failed: Too short phone number
     
=cut                                                                                                                            
     
                                                                                                                                
     
package SMS::Send::Labyrintti::Driver;                                                                                          

#use Modern::Perl; #Can't use this since SMS::Send uses hash keys starting with _                                               

use utf8;                                                                                                                       

use SMS::Send::Driver ();
use LWP::Curl;
use LWP::UserAgent;
use URI::Escape;
use C4::Context;
use Encode;
use Data::Dumper;

use vars qw{$VERSION @ISA};
BEGIN {
        $VERSION = '0.06';
                @ISA     = 'SMS::Send::Driver';
}


#####################################################################
# Constructor

sub new {
        my $class = shift;
        my $params = {@_};
        my $from = $params->{_from};
        my $dbh=C4::Context->dbh;
        my $branches=$dbh->prepare("SELECT branchcode FROM branches WHERE branchemail = ?;");
        $branches->execute($from);
        my $branch = $branches->fetchrow;
        my $code = substr($branch, 0, index($branch, '_'));
        my $username = $params->{_login} ? $params->{_login} : C4::Context->config('smsProviders')->{$code}->{'user'};
        my $password = $params->{_password} ? $params->{_password} : C4::Context->config('smsProviders')->{$code}->{'passwd'};
        
        if (! defined $username ) {
            warn "->send_sms(_login) must be defined!";
            return;
        }
        if (! defined $password ) {
            warn "->send_sms(_password) must be defined!";
            return;
        }
        
        #Prevent injection attack    
        $self->{_login} =~ s/'//g;
        $self->{_password} =~ s/'//g;
        
        # Create the object
        my $self = bless {}, $class;
        
        $self->{UserAgent} = LWP::UserAgent->new(timeout => 5);
        $self->{_login} = $username;
        $self->{_password} = $password;

        return $self;
}

sub send_sms {
    my $self    = shift;
    my $params = {@_};
    my $message = $params->{text};
    my $recipientNumber = $params->{to};
    
    if (! defined $message ) {
        warn "->send_sms(text) must be defined!";
        return;
    }
    if (! defined $recipientNumber ) {
        warn "->send_sms(to) must be defined!";
        return;
    }
    
    #Prevent injection attack!
    $recipientNumber =~ s/'//g;
    $message =~ s/(")|(\$\()|(`)/\\"/g; #Sanitate " so it won't break the system( iconv'ed curl command )
    
    my $base_url = "https://gw.labyrintti.com:28443/sendsms";
    my $parameters = {
        'user'      => $self->{_login},
        'password'  => $self->{_password},
        'dests'     => $recipientNumber,
        'text'      => $message,
        'unicode'   => 'yes'
    };

    my $lwpcurl = LWP::Curl->new();
    my $return = $lwpcurl->post($base_url, $parameters);

    return 1 if ($return =~ /OK [1-9](\d*)?/);
    return 0;

}
    
1;
