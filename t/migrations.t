use Mojo::Base -strict;

BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Test::More;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

use File::Spec::Functions 'catfile';
use FindBin;
use Mojo::mysql;

# Clean up before start
my $mysql = Mojo::mysql->new($ENV{TEST_ONLINE});
$mysql->db->query('drop table if exists mojo_migrations');

# Defaults
is $mysql->migrations->name,   'migrations', 'right name';
is $mysql->migrations->latest, 0,            'latest version is 0';
is $mysql->migrations->active, 0,            'active version is 0';

# Create migrations table
my $result = eval {
  $mysql->db->query('select * from mojo_migrations limit 1')
};
ok !$result,  'migrations table does not exist';

is $mysql->migrations->migrate->active, 0, 'active version is 0';
ok $mysql->db->query('select * from mojo_migrations limit 1')->array->[0], 'migrations table exists';

# Migrations from DATA section
is $mysql->migrations->from_data->latest, 0, 'latest version is 0';
is $mysql->migrations->from_data(__PACKAGE__)->latest, 0, 'latest version is 0';
is $mysql->migrations->name('test1')->from_data->latest, 7, 'latest version is 7';
is $mysql->migrations->name('test2')->from_data->latest, 2, 'latest version is 2';
is $mysql->migrations->name('test3')->from_data->latest, 12, 'latest version is 12';
is $mysql->migrations->name('migrations')->from_data(__PACKAGE__, 'test1')
  ->latest, 7, 'latest version is 7';
is $mysql->migrations->name('test2')->from_data(__PACKAGE__)->latest, 2,
  'latest version is 2';

# Different syntax variations
$mysql->migrations->name('migrations_test')->from_string(<<EOF);
-- 1 up
create table if not exists migration_test_one (foo varchar(255));

-- 1down

  drop table if exists migration_test_one;

  -- 2 up

insert into migration_test_one values ('works ♥');
-- 2 down
delete from migration_test_one where foo = 'works ♥';
--
--  3 Up, create
--        another
--        table?
create table if not exists migration_test_two (bar varchar(255));
-- 3  DOWN
drop table if exists migration_test_two;

-- 4 up (not down)
insert into migration_test_two values ('works too');
-- 4 down (not up)
delete from migration_test_two where bar = 'works too';
EOF
is $mysql->migrations->latest, 4, 'latest version is 4';
is $mysql->migrations->active, 0, 'active version is 0';
is $mysql->migrations->migrate->active, 4, 'active version is 4';
is_deeply $mysql->db->query('select * from migration_test_one')->hash,
  {foo => 'works ♥'}, 'right structure';
is $mysql->migrations->migrate->active, 4, 'active version is 4';
is $mysql->migrations->migrate(1)->active, 1, 'active version is 1';
is $mysql->db->query('select * from migration_test_one')->hash, undef,
  'no result';
is $mysql->migrations->migrate(3)->active, 3, 'active version is 3';
is $mysql->db->query('select * from migration_test_two')->hash, undef,
  'no result';
is $mysql->migrations->migrate->active, 4, 'active version is 4';
is_deeply $mysql->db->query('select * from migration_test_two')->hash,
  {bar => 'works too'}, 'right structure';
is $mysql->migrations->migrate(0)->active, 0, 'active version is 0';

# Bad and concurrent migrations
my $mysql2 = Mojo::mysql->new($ENV{TEST_ONLINE});
$mysql2->migrations->name('migrations_test2')
  ->from_file(catfile($FindBin::Bin, 'migrations', 'test.sql'));
is $mysql2->migrations->latest, 4, 'latest version is 4';
is $mysql2->migrations->active, 0, 'active version is 0';
eval { $mysql2->migrations->migrate };
like $@, qr/does_not_exist/, 'right error';
is $mysql2->migrations->migrate(3)->active, 3, 'active version is 3';
is $mysql2->migrations->migrate(2)->active, 2, 'active version is 3';
is $mysql->migrations->active, 0, 'active version is still 0';
is $mysql->migrations->migrate->active, 4, 'active version is 4';
is_deeply $mysql2->db->query('select * from migration_test_three')
  ->hashes->to_array, [{baz => 'just'}, {baz => 'works ♥'}],
  'right structure';
is $mysql->migrations->migrate(0)->active,  0, 'active version is 0';
is $mysql2->migrations->migrate(0)->active, 0, 'active version is 0';

# Unknown version
eval { $mysql->migrations->migrate(23) };
like $@, qr/Version 23 has no migration/, 'right error';

done_testing();

__DATA__
@@ test1
-- 7 up
create table migration_test_four (test int));

@@ test2
-- 2 up
create table migration_test_five (test int);

@@ test3
-- 1 up
CREATE TABLE "MyTable" (
    col1 text
);

-- 2 up
ALTER TABLE "MyTable" ADD COLUMN col2 text;

-- 3 up
ALTER TABLE "MyTable" ADD COLUMN col3 text;

-- 4 up
ALTER TABLE "MyTable" ADD COLUMN col4 text;

-- 5 up
ALTER TABLE "MyTable" ADD COLUMN col5 text;

-- 6 up
ALTER TABLE "MyTable" ADD COLUMN col6 text;

-- 7 up
ALTER TABLE "MyTable" ADD COLUMN col7 text;

-- 8 up
ALTER TABLE "MyTable" ADD COLUMN col8 text;

-- 9 up
ALTER TABLE "MyTable" ADD COLUMN col9 text;

-- 10 up
ALTER TABLE "MyTable" ADD COLUMN col10 text;

-- 11 up
ALTER TABLE "MyTable" ADD COLUMN col11 text;

-- 12 up
ALTER TABLE "MyTable" ADD COLUMN col12 text;
