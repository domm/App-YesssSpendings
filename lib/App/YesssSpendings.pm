package App::YesssSpendings;

use strict;
use warnings;
use 5.010;
use version; our $VERSION = version->new('0.02');
use WWW::Mechanize;
use Carp;
use DateTime;
use HTML::TableExtract;
use DateTime::Format::Strptime;
use Data::Dumper;
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Encode;
use utf8;

use Moose;
with qw(
    MooseX::Getopt);

has msisdn => (is=>'ro',isa=>'Str',required=>1);
has passwd => (is=>'ro',isa=>'Str',required=>1);
has mech   => (is=>'rw',isa=>'WWW::Mechanize',default=>sub { WWW::Mechanize->new( timeout=>300 ) });
has yesss_login  => (is=>'ro',isa=>'Str',default=>'http://www.yesss.at/kontomanager.php');
has type => (is=>'ro',isa=>'Str',required=>1); # wertkarte OR vertrag
has yesss_bookings=> (is=>'rw',isa=>'Str',lazy_build=>1);
sub _build_yesss_bookings {
    my $self = shift;
    return 'https://www.yesss.at/kontomanager/'.$self->type.'_gespraeche.php?'
}
has cost_per_call => (is=>'ro',lazy_build=>1);
sub _build_cost_per_call {
    my $self = shift;
    given ($self->type) {
        when ('wertkarte') { return 0.068 }
        when ('vertrag') { return 0.04 }
    }
}
has recipient=>(is=>'ro',isa=>'Str',required=>1);

has verbose => (is=>'rw',isa=>'Bool',default=>0);
has budget => (is=>'ro',isa=>'Str');
has session_id=>(is=>'rw',isa=>'Str');
has df_parser=>(is=>'ro',isa=>'DateTime::Format::Strptime',default=>sub {
    return DateTime::Format::Strptime->new(
        pattern  => '%d.%m.%Y',
        on_error => 'croak',
    );
});

no Moose;
__PACKAGE__->meta->make_immutable;

sub run {
    my $self = shift;

    $self->login;
    my ($subject,$body) = $self->get_this_months_bookings;

    my $email = Email::Simple->create(
        header => [
            To=>$self->recipient,
            From=>'YesssSpendings '.$self->msisdn.' <domm@plix.at>',
            Subject=>encode('MIME-Q',$subject),
            'Content-Type'=>'text/plain;charset=utf-8',
            'charset'=>'UTF-8',
            'Content-transfer-encoding'=>'quoted-printable',
        ],
        body=>encode_utf8($body),
    );
    sendmail($email);
}

sub login {
    my $self = shift;
    $self->mech->get($self->yesss_login);
    $self->mech->submit_form(
        with_fields=>{
            login_rufnummer=>$self->msisdn,
            login_passwort=>$self->passwd,
        }
    );
    if ($self->mech->uri->query =~ /(PHPSESSID=[\dabcdef]+)/) {
        $self->yesss_bookings($self->yesss_bookings . $1 .'&');
    }
}

sub get_this_months_bookings {
    my $self = shift;

    my $last_day_of_prev_month = DateTime->now->truncate('to'=>'month')->subtract('days'=>1);

    my $sum=0;
    my $cost_per_call = $self->cost_per_call;
    my %types;
    my ($subject,@body);
    PAGE: foreach my $page (1 .. 20) {
        my $table_extract = HTML::TableExtract->new();#headers => ['Datum/Uhrzeit:',qw(Nummer: Dauer: Kosten: Art:)]);
        $self->mech->get($self->yesss_bookings . "page=$page");
        
        $table_extract->parse($self->mech->content);
        foreach my $row ($table_extract->rows) {
            next if $row->[0] =~ /datum/i;
            my $rawdate = substr($row->[0],0,10);
            my $date = $self->df_parser->parse_datetime($rawdate);
            last PAGE if $date <= $last_day_of_prev_month;
            say join(';',$date->ymd,$row->[4],$row->[5]) if $self->verbose;
            $sum+=$row->[4];
            $types{$row->[5]}++;
        }
    }  
    
    # compare with budget
    if (my $budget = $self->budget) {
        my $now = DateTime->now->truncate('to'=>'day');
        my $days = DateTime->last_day_of_month(year=>$now->year,month=>$now->month)->day || 30;
        my $soll = sprintf("%5.3f",($budget/$days) * $now->day);
        push(@body,"Ausgegeben: $sum Euro");
        push(@body,"Budget bis heute: $soll Euro");
        push(@body,"Budget dieses Monat: $budget");
        my $rest = $soll - $sum;
        my $total_rest = $budget - $sum;
        push(@body,"Rest: $total_rest");
        if ($rest > 0) {
            my $sms_left = int($rest / $cost_per_call);
            $subject = "Noch $sms_left SMS/Telefonate möglich";
        }
        else {
            my $sms_left = int($total_rest / $cost_per_call);
            $subject = "STOP! Du bis drüber!";
            push(@body,"Noch $sms_left SMS/Telefonate in diesem Monat möglich");
        }
        $subject .= ' ('.$sum.'/'.$soll.')';
        push(@body,$subject);
        push(@body, join(', ',map { "$_: ".$types{$_} } keys %types));
    }
    else {
        push(@body, $sum);
    }
    return ($subject,join("\n",@body));
}

1;

__END__

=head1 NAME

App::YesssSpendings - Inform on this months yesss spendings

=head1 SYNOPSIS

  use App::YesssSpendings;

=head1 DESCRIPTION

App::YesssSpendings is a quick hack to screenscape the yesss.at 
(Austrian prepaid mobile provider) to get the sum of this months 
spendings (so I can tell my son when to stop texting!!!)

=head1 AUTHOR

Thomas Klausner E<lt>domm {at} cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
