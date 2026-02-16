#!/usr/bin/env perl
use Mojolicious::Lite;
use Path::Tiny;
use TOML::Tiny 'from_toml';
use lib 'lib';

# --- CONFIGURATION ---
my $config = from_toml(path('config.toml')->slurp_utf8);
my $tcp_config = $config->{tcp_service};
# --- END CONFIGURATION ---

# --- FACTORY ---
use Factory;
my $factory = Factory->new(
    tcp_config => $tcp_config,
    logger     => app->log,
);
# --- END FACTORY ---

# --- CONTROLLERS ---
use Controller::Index;
my $rows_controller = $factory->rows_controller;
# --- END CONTROLLERS ---

get '/' => sub {
    my $c = shift;
    Controller::Index::handler($c);
};

get '/rows' => sub {
    my $c = shift;
    $rows_controller->handler($c);
};

# Mojolicious will automatically detect and use the public directory
app->start;
