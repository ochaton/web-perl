package MyWeb;
use Dancer2;
use Dancer2::Plugin::Passphrase;

our $VERSION = '0.1';

set session => 'YAML';

use DBI;
use DDP;
my $dbh = DBI->connect('dbi:mysql:database=Sfera;' . 'host=localhost;port=3306', 'root', 'imagination');

sub get_next_token {
    my $user_id = session('user');

    my $sql = 'SELECT * FROM `users` where id=?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;

    $sth->execute($user_id) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref;
    use Digest::SHA qw (sha256_hex);

    my $str = "";
    for (0..int(rand(25))) {
        $str .= $row->{email};
        $str .= $row->{nick};
    }

    $str .= localtime();

    my $token = sha256_hex($str);
    $sql = 'UPDATE `users` set token=? where id=?';
    $sth = $dbh->prepare($sql) or die $dbh->errstr;

    $sth->execute($token, $row->{id}) or die $sth->errstr;
    p $token;
}

sub send_to_db {
    my $user_info = shift;
    return unless defined $user_info;

    my $sql_first = 'UPDATE `users` SET';
    my $sql_inner = '';
    my $sql_last = 'WHERE id=?';

    my @sql_params;

    if (defined $user_info->{nick}) {

        my $sth_check = $dbh->prepare('SELECT id FROM `users` WHERE nick=?')
            or die $dbh->errstr;

        $sth_check->execute($user_info->{nick})
            or die $sth_check->errstr;

        my $ans = $sth_check->fetchrow_hashref;
        return 0 if (defined $ans && $ans->{id} != session('user'));

        $sql_inner .= ' nick=? ';
        push @sql_params, $user_info->{nick};
    }
    if (defined $user_info->{email}) {

        my $sth_check = $dbh->prepare('SELECT id FROM `users` WHERE email=?')
            or die $dbh->errstr;

        $sth_check->execute($user_info->{email})
            or die $sth_check->errstr;

        my $ans = $sth_check->fetchrow_hashref;
        return 0 if (defined $ans && $ans->{id} != session('user'));


        $sql_inner .= ' email=? ';
        push @sql_params, $user_info->{email};
    }

    push @sql_params, session('user');

    p @sql_params;

    my $sql = $sql_first . $sql_inner . $sql_last;
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute(values @sql_params) or die $sth->errstr;

    1;
}

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
    my $request_body = request->body();

    p $request_body;

    unless (session('user')) {
        status 'not_found';
        redirect '/404';
    }

    if ($request_body =~ m{^exit_button}) {
        session user => undef;
        redirect '/';
    } 
    elsif ($request_body =~ m{^token_button}) { 
        get_next_token();
        redirect '/';
    }
    elsif ($request_body =~ m{^home_button}) {
        redirect '/';
    }
    elsif ($request_body =~ m{change_button=Send$}) {
        
        my $res;

        if (param('change_nick')) {
            $res = send_to_db({nick => param('change_nick')});
        }
        if (param('change_email')) {
            $res = send_to_db({email => param('change_email')});
        }
        redirect '/' if ($res);
        
        unless ($res) {
            session user => undef;
            redirect '/';
        }
    }
    else {
        redirect request->dispatch_path;
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
    

    my $sql = 'SELECT * FROM `users` WHERE email=? or nick=?';
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

    get_next_token();

    session user => $row->{id};
    redirect '/user0';
};

dance();

true;
