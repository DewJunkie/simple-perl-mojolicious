#!/usr/bin/env perl
use IO;
$s=IO::Socket::INET->new(LocalPort=>1337,Listen=>1,ReuseAddr=>1);
while($c=$s->accept()){
    print $c q{x}x200;
    sleep 1;
    close $c
}