package Factory;

use strict;
use warnings;

use Business::Service;
use Controller::Rows;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    return $self;
}

sub logger {
    my ($self) = @_;
    return $self->{logger};
}

sub tcp_config {
    my ($self) = @_;
    return $self->{tcp_config};
}

sub business_service {
    my ($self) = @_;
    return Business::Service->new(log => $self->logger());
}

sub rows_controller {
    my ($self) = @_;
    return Controller::Rows->new(
        business_service => $self->business_service(),
        tcp_config       => $self->tcp_config(),
    );
}

1;
