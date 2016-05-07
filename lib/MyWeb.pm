package MyWeb;
use Dancer2;

our $VERSION = '0.1';

set session => "Simple";

use DBI;
my $dbh = DBI->connect('dbi:mysql:database=Sfera;' . 'host=localhost;port=3306', 'root', 'imagination');

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

get '/user:id?' => sub {

	my $sql = 'SELECT * FROM `users` WHERE id=?';
	my $sth = $dbh->prepare($sql) or die $dbh->errstr;
	$sth->execute(param('id')) or die $sth->errstr;

	my $row = $sth->fetchrow_hashref;
	warn 'get user' . param('id');
	
	use DDP;
	p $row;

	unless (defined $row) {
		status 'not_found';
		redirect '/404';
		return;
	}

	template 'user_page.tt',
	{
		'user_img' => 'img_src',
		'user_nick' => $row->{'nick'},
		'user_email' => $row->{'email'},
		'user_token' => $row->{'token'},
	}
};

post '/auth' => sub {
	my (@args) = @_;

	use DDP;
	# (email, password, sig)

	my $email = params->{'email'};
	my $password = params->{'password'};
	my $sig = params->{'sig'};

	my $sql = 'SELECT * FROM `login` WHERE email = ?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    
    $sth->execute(params->{'email'}) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref;
    p $row;

	if (
    	defined $row and
    	$row->{'email'} eq $email and
    	$row->{'PASSWORD'} eq $password
    	) 
	{

    	redirect '/user' . $row->{user_id};
    }
   	else {
   		template 'auth',
		{
			'wrong_login_pass' => 'block',
		};
   	}
};

post '/reg' => sub {
	my (@args) = @_;

	if (params->{password} ne params->{passcheck}) {
		template 'ok',
		{
			'msg' => 'WA!<br />Пароли не совпадают!',
		};
		return ;
	}

	my $sql = 'SELECT * FROM `login` WHERE email=?';
	my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    
    $sth->execute(params->{'email'}) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref;
    p $row;

    if (defined $row) {
    	template 'ok',
    	{
    		'msg' => 'WA!<br />Пользователь с таким email уже существует!',
    	};
    	return ;
    }

	my $user_info = {
		nick => params->{'nick'},
		email => params->{'email'},
		password => params->{'password'},
	};

	$sql = 'INSERT INTO `users` (nick, email, token) VALUES (?, ?, ?)';
	$sth = $dbh->prepare($sql) or die $dbh->errstr;
	$sth->execute($user_info->{nick}, $user_info->{email}, $user_info->{nick} . $user_info->{email}) or 
		die $sth->errstr;

	$sql = 'SELECT id FROM `users` WHERE nick = ?';
	$sth = $dbh->prepare($sql) or die $dbh->errstr;
	$sth->execute($user_info->{nick}) or die $dbh->errstr;

    $row = $sth->fetchrow_hashref;
    p $row;

    unless (defined $row) {
		template 'ok',
		{
        	'msg' => '502. Internal Error! <br />',
		};
    };
    
    $sql = 'INSERT INTO `login` (email, password, user_id) VALUES (?, ?, ?)';
	$sth = $dbh->prepare($sql) or die $dbh->errstr;
	$sth->execute($user_info->{email}, $user_info->{password}, $row->{id}) or die $dbh->errstr;

    template 'ok',
    {
    	'msg' => 'User created successfully!<br />',
    };

};

true;
