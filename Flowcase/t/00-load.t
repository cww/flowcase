#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Flowcase' ) || print "Bail out!\n";
}

diag( "Testing Flowcase $Flowcase::VERSION, Perl $], $^X" );
