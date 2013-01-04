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

package Flowcase;

use common::sense;

use Getopt::Long;
use Moose;

use Flowcase::WebHandler;

# Default listen IP address.
use constant DEFAULT_LISTEN_ADDRESS => '0.0.0.0';

# Default delay between page transitions, in seconds.
use constant DEFAULT_PAGE_DELAY => 60;

# Default port on which to listen for web requests.
use constant DEFAULT_LISTEN_PORT => 8958;

# Default path for page model modules.
use constant DEFAULT_MODULE_PATH => 'Flowcase::Pages';

# Command-line options definition.
use constant OPTS =>
[qw(
    help
    address|a=s config|c=s% delay|d=i module_path|m=s
    port|p=i tmpl_dir|t=s exclude|x=s
)];

=head1 NAME

Flowcase - A web-based slideshow of any content you want!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Run the Flowcase application.

    use Flowcase;

    my $flowcase = Flowcase->new();
    my $exit_code = $flowcase->start();
    exit $exit_code;

=head1 SUBROUTINES/METHODS

=cut

our $_singleton;
sub get_instance
{
    return $_singleton;
}

has 'listen_address' =>
    ( isa => 'Str', is => 'rw', default => DEFAULT_LISTEN_ADDRESS );
has 'page_delay' =>
    ( isa => 'Num', is => 'rw', default => DEFAULT_PAGE_DELAY );
has 'listen_port' =>
    ( isa => 'Num', is => 'rw', default => DEFAULT_LISTEN_PORT );
has 'module_path' =>
    ( isa => 'Str', is => 'rw', default => DEFAULT_MODULE_PATH );
has 'tmpl_dir' =>
    ( isa => 'Str', is => 'rw' );
has 'exclude' =>
    ( isa => 'Str', is => 'rw' );
has 'config' =>
    ( isa => 'HashRef', is => 'rw');

=head2 start()

Start Flowcase.  Parse command-line options and begin the main loop.

=cut
sub start
{
    die('Too many instances of ' . __PACKAGE__) if $_singleton;
    my ($self) = @_;

    $_singleton = $self;

    $self->parse_opts();

    say 'Options to be used:';
    say ">> Listen address: $self->{listen_address}";
    say ">> Listen port: $self->{listen_port}";
    say ">> Module path: $self->{module_path}";
    say ">> Page delay: $self->{page_delay}";
    say ">> Template directory: $self->{tmpl_dir}";
    say '>> Pages to exclude:';
    say '    (none)' if scalar(@{$self->{exclude}}) == 0;
    foreach (sort { $a cmp $b } @{$self->{exclude}})
    {
        say "    $_";
    }
    say '>> Config options:';
    say '    (none)' if scalar(keys %{$self->{config}}) == 0;
    foreach (sort { $a cmp $b } keys %{$self->{config}})
    {
        say "    '$_' => '$self->{config}->{$_}'";
    }

    Flowcase::WebHandler->new()->start();

    # Return a UNIX-style exit code.
    return 0;
}

sub _usage
{
    my ($self, $errors_ref) = @_;

    if ($errors_ref && scalar(@$errors_ref) > 0)
    {
        say STDERR "ERROR: Missing or invalid value for option(s):";
        say "    $_" for (@$errors_ref);
        say q{};
    }

    say 'Usage: flowcase -t directory [-d number]';
    say 'Required arguments:';
    say '    -t directory         Directory that contains HTML templates';
    say 'Optional arguments:';
    say '    -a address           IP address on which to listen for web';
    say '                         requests [', DEFAULT_LISTEN_ADDRESS, ']';
    say '    -d number            Delay, in seconds, between page';
    say '                         transitions [', DEFAULT_PAGE_DELAY, ']';
    say '    -m path              Perl module path for page models';
    say '                         [', DEFAULT_MODULE_PATH, ']';
    say '    -p port              Port on which to listen for web requests';
    say '                         [', DEFAULT_LISTEN_PORT, ']';
    say '    -x pages             Comma-separated list of page files to ';
    say '                         exclude';

    exit($errors_ref ? -1 : 0);
}

=head2 parse_opts()

Parse command-line options and store them (or defaults) in $self.

=cut
sub parse_opts
{
    my ($self) = @_;

    my %opts;
    GetOptions(\%opts, @{+OPTS});

    $self->_usage() if $opts{help};

    my @errors;

    if (defined($opts{address}))
    {
        $self->listen_address($opts{address});
    }

    if (defined($opts{delay}))
    {
        if ($opts{delay} !~ /^\d+$/ || $opts{delay} < 1)
        {
            push(@errors, 'Delay must be 1 or greater');
        }
        else
        {
            $self->page_delay($opts{delay});
        }
    }

    if (defined($opts{module_path}))
    {
        $self->module_path($opts{module_path});
    }

    if (defined($opts{port}))
    {
        if ($opts{port} =~ /^\d+$/)
        {
            if ($opts{port} <= 0 || $opts{port} >= 65536)
            {
                push(@errors, 'Port must be between 0 and 65536, exclusive');
            }
            elsif ($> != 0 && $opts{port} <= 1024)
            {
                push(@errors, 'Non-root users are restricted to high ports');
            }
            else
            {
                $self->listen_port($opts{port});
            }
        }
        else
        {
            push(@errors, 'Port must be numeric');
        }
    }

    if (defined($opts{tmpl_dir}))
    {
        if (-d $opts{tmpl_dir})
        {
            $self->tmpl_dir($opts{tmpl_dir});
        }
        else
        {
            push(@errors, 'Template directory must exist');
        }
    }
    else
    {
        push(@errors, 'Template directory must be provided');
    }

    $self->{exclude} = $opts{exclude} ? [ split(q{,}, $opts{exclude}) ] : [];

    if (defined($opts{config}))
    {
        $self->{config} = $opts{config};
    }

    $self->_usage(\@errors) if (scalar @errors > 0)
}

=head1 AUTHOR

Colin Wetherbee, C<< <cww at cpan.org> >>

=head1 BUGS

Please report any bugs using the GitHub issue tracker for this project.

L<https://github.com/cww/flowcase/issues>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Flowcase

=head1 LICENSE AND COPYRIGHT

Please see the LICENSE file included in this distribution for the terms under
which this software is licensed.

Additionally, each source file includes a copyright notice and brief licensing
terms.

=cut

1;
