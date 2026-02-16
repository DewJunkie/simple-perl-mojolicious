package Controller::Index;

use strict;
use warnings;

sub handler {
    my ($c) = @_;
    my $vars = {
        title => 'Modern Perl Layout',
        tabs => [
            { name => 'Home', link => '/', is_active => 1 },
            { name => 'Products', link => 'products', is_active => 0 },
            { name => 'About', link => 'about', is_active => 0 },
            { name => 'Contact', link => 'contact', is_active => 0 },
        ],
    };
    $c->render(template => 'index', %$vars);
}

1;
