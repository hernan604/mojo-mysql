use Mojo::Base -strict;
use Mojolicious::Lite;
use Mojo::mysql;
use Test::More;
use Test::Mojo;

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};
my $mysql = Mojo::mysql->new($ENV{TEST_ONLINE});

$mysql->db->do(
  'create table if not exists results_test (
     id serial primary key,
     name varchar(255)
   )'
);
$mysql->db->query('insert into results_test (id, name) values (1, "test row")');

get '/' => sub {
  my ($c) = @_;
  $c->delay(
    sub {
      my ($delay) = @_;
      $mysql->db->query("SELECT * FROM results_test WHERE id = 1" => $delay->begin);
    },
    sub {
      my ($delay, $err, $result) = @_;
      my $hash = $result->hash;
      $c->render(json => $hash);
    }
  );
};

my $t = Test::Mojo->new;

$t->get_ok('/')->status_is(200)->json_is('/id', 1)->json_is('/name', 'test row');
$mysql->db->do('drop table results_test');

done_testing;
