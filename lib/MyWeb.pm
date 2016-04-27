package MyWeb;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/hello' => sub {
	template 'hello.tt', 
	{
		'value' => 4156234,
	};
};

get '/reg' => sub {
	template 'registration.tt',
	{
		'csrf_value' => 123123,
	};
};

get '/auth' => sub {
	template 'auth.tt',
	{
		'csrf_value' => 123123,
	};
}

post '/reg' => sub {
	my (@args) = @_;
	
	use Data::Dumper;
	use FindBin;

	open (my $dh, '>', $FindBin::Bin . '/../logs.txt');
	$dh->print(Dumper(\@args));
	close($dh);

	my $some_var = 123;
	template 'ok'
};

true;
