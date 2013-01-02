# Copyright 2012, 2013 Colin Wetherbee
#
# This file is part of Flowcase.
#
# Flowcase is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Flowcase is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Flowcase.  If not, see <http://www.gnu.org/licenses/>.

package Flowcase::Pages::Market;

use common::sense;

use Finance::Quote;
use Moose;

use constant DEFAULT_HEADLINE_SYMBOL => '^GSPC';
use constant DEFAULT_SYMBOL_LIST => 'CNX,IVR,AGNC,BRKB,GLD';
use constant QUOTE_LOCATION => 'usa';

has 'headline_symbol' =>
    (is => 'ro', isa => 'Str', default => DEFAULT_HEADLINE_SYMBOL);
has 'symbol_list' =>
    (is => 'ro', isa => 'Str', default => DEFAULT_SYMBOL_LIST);

sub BUILD
{
    my ($self) = @_;

    $self->{quote} = Finance::Quote->new();
    $self->{quote}->timeout(6);
}

sub cache_ttl { 60 };

sub get_vars
{
    my ($self) = @_;

    say 'Getting data for headline symbol: ', $self->headline_symbol();
    my $headline_data_ref = $self->_strip_symbol(
                            $self->_fetch(
                            $self->headline_symbol() ));

    say 'Getting data for symbols: ', $self->symbol_list();
    my $data_ref = $self->_reformat(
                   $self->_fetch(
                   split(q{,}, $self->symbol_list()) ));

    my %page_data =
    (
        headline_data => $headline_data_ref,
        data => $data_ref,
    );
    return \%page_data;
}

sub _fetch
{
    my ($self, @symbols) = @_;

    return $self->{quote}->fetch(QUOTE_LOCATION, @symbols);
}

sub _reformat
{
    my ($self, %data_ref) = @_;

    my %new_data;

    while (my ($key, $value) = each %data_ref)
    {
        my ($symbol, $subkey) = split(chr(0x1c), $key);
        $new_data{$symbol}->{$subkey} = $value;
    }

    return \%new_data;
}

sub _strip_symbol
{
    my ($self, %data_ref) = @_;

    my %new_data;

    while (my ($key, $value) = each %data_ref)
    {
        my (undef, $subkey) = split(chr(0x1c), $key);
        $new_data{$subkey} = $value;
    }

    return \%new_data;
}

1;
