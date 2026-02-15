# cpanfile
requires 'Mojolicious';
requires 'Path::Tiny';
requires 'TOML::Tiny';

on 'develop' => sub {
    requires 'Carton';
};