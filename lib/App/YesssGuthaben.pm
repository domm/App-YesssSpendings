package App::YesssGuthaben;

use strict;
use warnings;
use 5.010;
use version; our $VERSION = version->new('0.01');
use WWW::Mechanize;
use Carp;
use DateTime;
use HTML::TableExtract;

use Moose;
with qw(
    MooseX::Getopt);

has msisdn => (is=>'ro',isa=>'Str',required=>1);
has passwd => (is=>'ro',isa=>'Str',required=>1);
has mech   => (is=>'rw',isa=>'WWW::Mechanize',default=>sub { WWW::Mechanize->new });
has yesss_login  => (is=>'ro',isa=>'Str',default=>'http://www.yesss.at/kontomanager.php');
has yesss_bookings=> (is=>'ro',isa=>'Str',default=>'https://www.yesss.at/kontomanager/wertkarte_gespraeche.php?page=');
has verbose => (is=>'rw',isa=>'Bool',default=>0);

no Moose;
__PACKAGE__->meta->make_immutable;

sub run {
    my $self = shift;

    $self->login;
    $self->get_this_months_bookings; 
}

sub login {
    my $self = shift;
    $self->mech->get($self->yesss_login);
    $self->mech->submit_form(
        with_fields=>{
            rufnummer=>$self->msisdn,
            passwort=>$self->passwd,
        }
    );
}

sub get_this_months_bookings {
    my $self = shift;

    my $last_day_of_prev_month = DateTime->now->truncate('to'=>'month')->subtract('days'=>1)->dmy('.');

    my $sum;
    PAGE: foreach my $page (1 .. 10) {
        my $table_extract = HTML::TableExtract->new(headers => ['Datum/Uhrzeit:',qw(Nummer: Dauer: Kosten: Art: Verrechnung:)]);
        $self->mech->get($self->yesss_bookings . $page);
        $table_extract->parse($self->mech->content);
        foreach my $row ($table_extract->rows) {
            my $date = substr($row->[0],0,10);
            last PAGE if $date eq $last_day_of_prev_month; 
            say join(';',$date,$row->[3],$row->[4]) if $self->verbose;
            $sum+=$row->[3];
        }
    }  
    say $sum;
}

1;

__END__

=head1 NAME

App::YesssGuthaben - Inform on this months yesss spendings

=head1 SYNOPSIS

  use App::YesssGuthaben;

=head1 DESCRIPTION

App::YesssGuthaben is a quick hack to screenscape the yesss.at 
(Austrian prepaid mobile provider) to get the sum of this months 
spendings (so I can tell my son when to stop texting!!!)

=head1 AUTHOR

Thomas Klausner E<lt>domm {at} cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
