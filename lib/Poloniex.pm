package Poloniex;
#use strict;
#use warnings;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use PHP::HTTPBuildQuery qw(http_build_query);
use Digest::SHA qw(hmac_sha512_hex);
use LWP::UserAgent;
use JSON::XS;
use WWW::Curl::Easy;
use Test::JSON;
use Config::Simple;
use Scalar::Util 'blessed';
use Helper;
use Data::Dumper;

our $VERSION='0.01';

sub new
{
    my $class = shift;
    my %opts  = @_;
    
    my $self = {
    	%opts
    };
    
    bless $self, $class;
    $self->initialize(@_);
    return $self;
}

sub initialize
{
    my $self = shift;
 
	$self->{trading_url} = "https://poloniex.com/tradingApi";
    $self->{public_url} = "https://poloniex.com/public";
}


sub query {
 my $self = shift;
 my %req = %{$_[0]};

 # API unique settings
 my $key = $self->{api_key};
 my $secret = $self->{api_secret};

 $req{'nonce'} = int time;
 $req{'nonce'} = $req{'nonce'}*2000000;

 my $data = \%req;

 # Generate the POST data string
 my $post_data = http_build_query($data, '', '&');
 my $sign = hmac_sha512_hex($post_data, $secret);

 my @headers = ("Key: $key", "Sign: $sign",);

 my $curl = WWW::Curl::Easy->new;
 $curl->setopt( CURLOPT_URL, $self->{trading_url} );
 $curl->setopt( CURLOPT_POSTFIELDS, $post_data );
 $curl->setopt( CURLOPT_HTTPHEADER, \@headers );
 
 my $response_body;
 
 $curl->setopt( CURLOPT_WRITEDATA, \$response_body );

 log Dumper(\$data);


 # Send request
 my $retcode = $curl->perform;
 
 log "Reply: ".$response_body;
 
 
 
 if ($retcode == 0) {
  my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
  if (my $dec = JSON::XS::decode_json($response_body)) {
   if (ref($dec) eq "HASH") { return %{  $dec  }; } else { return  @{  $dec  }; }
  } else { return }
 }

 die "An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf;
}

sub retrieveJSON {
 my $self = shift;
 my $URL = shift;
 my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
 my $res = $ua->get($URL);
 my $records = $res->decoded_content;
 my $json = JSON::XS::decode_json($records);
 return $json;
}

sub get_ticker {
 my $self = shift; 
 my $pair = shift;
 
 my $prices = $self->retrieveJSON($self->{public_url} . '?command=returnTicker');
 
 if (!$pair || ($pair eq "ALL")) { return %{$prices}; } # Dereference the hash reference
 else {
  $pair = uc($pair);
  if ($prices->{$pair}) { return %{$prices->{$pair}}; } else { return {}; } # Dereference the hash reference or return empty anon hash
 }
}

sub get_trade_history {
 my $self = shift; 
 my $pair = shift;
 
 my $trades = $self->retrieveJSON($self->{public_url} . '?command=returnTradeHistory&currencyPair=' . uc($pair));
 
 return @{$trades};
}


sub get_order_book 
{
 my $self = shift; 
 my $pair = shift;
 
 my $orders = $self->retrieveJSON($self->{public_url} . '?command=returnOrderBook&currencyPair=' . uc($pair));
 
 return %{$orders};
}

sub get_volume
{
 my $self = shift; 
 my $volume = shift;
 
 $volume = $self->retrieveJSON($self->{public_url} . '?command=return24hVolume');
 
 return %{$volume};
}

sub get_trading_pairs
{
 my $self = shift;
 
 my $tickers = $self->retrieveJSON($self->{public_url} . '?command=returnTicker');
 
 return $tickers;
}


sub get_balances
{
 my $self = shift;

 return $self->query(
  {
   command => 'returnBalances'
  }
 );
}


sub get_open_orders
{ # Returns array of open order hashes
 my $self = shift; 
 my $pair = shift;
 
 return $self->query(
  {
   'command' => 'returnOpenOrders',
   'currencyPair' => uc($pair)
  }
 );
}

sub get_my_trade_history
{
 my $self = shift; 
 my $pair = shift;
 
 return $self->query(
  {
   'command' => 'returnTradeHistory',
   'currencyPair' => uc($pair)
  }
 );
}


sub buy
{
 my $self = shift; 
 my $pair = shift; 
 my $rate = shift; 
 my $amount = shift;
 
 return $self->query(
  {
   'command' => 'buy',
   'currencyPair' => uc($pair),
   'rate' => $rate,
   'amount' => $amount
  }
 );
}

sub sell
{
 my $self = shift; 
 my $pair = shift; 
 my $rate = shift; 
 my $amount = shift;
 
 return $self->query(
  {
   'command' => 'sell',
   'currencyPair' => uc($pair),
   'rate' => $rate,
   'amount' => $amount
  }
 );
}

sub cancel_order
{
 my $self = shift; 
 my $pair = shift; 
 my $order_number = shift;
 
 return $self->query(
  {
   'command' => 'cancelOrder',
   'currencyPair' => uc($pair),
   'orderNumber' => $order_number
  }
 );
}

sub withdraw
{
 my $self = shift; 
 my $currency = shift; 
 my $amount = shift; 
 my $address = shift;
 
 return $self->query(
  {
   'command' => 'withdraw',
   'currency' => uc($currency),
   'amount' => $amount,
   'address' => $address
  }
 );
}


sub public_url {
 my $self = shift;
 
 if (@_) {
  $self->{public_url} = shift;
 }
 
 return $self->{public_url};
}

1;
