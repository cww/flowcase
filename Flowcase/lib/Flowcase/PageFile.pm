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

package Flowcase::PageFile;

use common::sense;

use Moose;

use overload q{""} => sub
{
    my ($self) = @_;
    return $self->classname();
};

has 'filename' => (is => 'ro', isa => 'Str');
has 'pagename' => (is => 'ro', isa => 'Str');
has 'classname' => (is => 'ro', isa => 'Str');
has 'module' => (is => 'ro', isa => 'Str');

sub BUILD
{
    my ($self) = @_;

    my $page = $self->pagename();
    $page =~ s/\..*$//;
    $page =~ s/^(.)/uc($1)/e;
    $self->{classname} = $page;
    $self->{module} = Flowcase::get_instance()->module_path() . '::' . $page;
}

1;
