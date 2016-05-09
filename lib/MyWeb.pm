package MyWeb;
use Dancer2;
use Dancer2::Plugin::Passphrase;

our $VERSION = '0.1';

set session => 'YAML';

use DBI;
my $dbh = DBI->connect('dbi:mysql:database=Sfera;' . 'host=localhost;port=3306', 'root', 'imagination');

hook before => sub {
    if (!session('user') && 
            (request->dispatch_path !~ m{^/auth} && 
             request->dispatch_path !~ m{^/reg})
        ) {
        redirect '/auth';
    }
    if (session('user')) {
        if (request->dispatch_path =~ m{^(/auth|/reg)}) {
            redirect '/user0';
        }
    }
};

get '/' => sub {
    if (session('user')) {
        redirect '/user0';
    }
    else {
        redirect '/auth';
    }
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

    if (param('id') == 0) {
        redirect '/user' . session('user');
    }

    my $mypage = undef;

    if (param('id') == session('user')) {
        $mypage = 'true';
    }

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
        'my_user_page' => $mypage,
    }
};

post '/user:id?' => sub {
    if (session('user')) {
        session user => undef;
        redirect '/';
    } else {
        status 'not_found';
        redirect '/404';
    }
};

post '/auth' => sub {
    my (@args) = @_;

    use DDP;
    # (email, password, sig)

    my $email = params->{email};
    my $password = params->{password};
    my $sig = params->{sig};

    my $sql = 'SELECT * FROM `users` WHERE email = ?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    
    $sth->execute(params->{email}) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref;
    p $row;

    if (
        defined $row and
        $row->{email} eq $email and
        passphrase($password)->matches($row->{password})
        ) 
    {
        session user => $row->{id};
        redirect '/user' . $row->{id};
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

    if (!params->{email} || !params->{nick} || !params->{password}) {
        # empty fields
        return template 'reg', 
        {
            'wrong_form_data' => 'block',
            'message' => 'You should fill all fields of form',
        };
    }

    if (params->{password} ne params->{passcheck})  {
        return template 'reg', 
        {
            'wrong_form_data' => 'block',
            'message' => 'Passwords are not the same',
        };
    }
    

    my $sql = 'SELECT * FROM `users` WHERE email=? and nick=?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    
    $sth->execute(params->{email}, params->{nick}) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref;
    p $row;

    if (defined $row) {
        return template 'reg',
        {
            'wrong_form_data' => 'block',
            'message' => 'Пользователь с такими данными уже существует!',
        };
    }

    my $user_info = {
        nick => params->{nick},
        email => params->{email},
        password => passphrase(params->{password})->generate->rfc2307,
    };

    $sql = 'INSERT INTO `users` (nick, email, password, token) VALUES (?, ?, ?, ?)';
    $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute
    (
        $user_info->{nick}, 
        $user_info->{email}, 
        $user_info->{password}, 
        $user_info->{nick} . $user_info->{email}
    ) or die $sth->errstr;

    $sql = 'SELECT id FROM `users` WHERE nick = ?';
    $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($user_info->{nick}) or die $dbh->errstr;

    $row = $sth->fetchrow_hashref;
    p $row;

    unless (defined $row) {
        return template 'reg',
        {
            'wrong_form_data' => 'block',
            'message' => '502. Internal Error!',
        };
    };

    session user => $row->{id};
    redirect '/user0';
};

dance();

true;
