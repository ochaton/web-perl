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
	template 'reg.tt',
	{
		'csrf_value' => 123123,
	};
};

get '/auth' => sub {
	template 'auth.tt',
	{
		'csrf_value' => 123123,
	};
};

post '/auth' => sub {
	my (@args) = @_;

	use DDP;
	# (email, password, sig)

	my $email = params->{'email'};
	my $password = params->{'password'};
	my $sig = params->{'sig'};

	use DBI;
	my $dbh = DBI->connect('dbi:mysql:database=Sfera;' . 'host=localhost;port=3306', 'root', 'imagination');
	my $sql = 'SELECT * FROM `users` WHERE email = ?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    
    $sth->execute(params->{'email'}) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref;
    p $row;

    if ( 
    	defined $row and 
    	$row->{'email'} eq params->{'email'} and
    	$row->{'password'} eq params->{'password'}
    ) 
   	{
		template 'ok',
		{
			'msg' => 'OK!',
		};
	}
	else 
	{
		template 'auth',
		{
			'wrong_login_pass' => 'block',
		};
	}
};

post '/reg' => sub {
	
}

true;
