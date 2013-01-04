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

package Flowcase::WebHandler;

use common::sense;

use File::Glob;
use HTTP::Daemon;
use HTTP::Status qw();
use List::MoreUtils;
use List::Util qw(shuffle);
use Moose;
use Time::HiRes;

use Flowcase;
use Flowcase::PageCache;
use Flowcase::PageFile;

use constant ACCEPT_TIMEOUT => 2;

sub start
{
    my ($self) = @_;

    local $| = 1;
    
    my $server = $self->_start_server();

    my $cache = Flowcase::PageCache->new();
    my $finished = 0;

    my $flowcase = Flowcase::get_instance();

    my $bad_files_ref = $self->_load_file_lists($flowcase->exclude());
    if (scalar(@$bad_files_ref) > 0)
    {
        die 'Bad files in template directory: ',
            join(q{, }, @$bad_files_ref);
    }
    elsif (scalar(@{$self->{page_files}}) == 0)
    {
        die 'No files to serve in template directory: ',
            $flowcase->tmpl_dir();
    }

    my $cycle_page_files_ref = [ shuffle(@{$self->{page_files}}) ];
    my $cur_page = $cycle_page_files_ref->[0];
    my $cycle_timer = time();
    say "Active page is now [$cur_page]";

    local $SIG{INT} = sub
    {
        say 'Interrupt!';
        $finished = 1;
    };

    say 'Listening for new connections';

    while (!$finished)
    {
        if (time() > $cycle_timer + Flowcase::get_instance()->page_delay())
        {
            $cur_page = pop(@$cycle_page_files_ref);
            unshift(@$cycle_page_files_ref, $cur_page);
            $cycle_timer = time();
            say "Active page is now [$cur_page]";
        }

        my $c = $server->accept();
        next unless $c;

        while (my $r = $c->get_request())
        {
            if ($r->method() eq 'GET')
            {
                my $url = $r->uri()->path();
                say "Request for URL [$url]";
                $url =~ s|^/||;
                my $page_to_load;

                if ($url eq q{})
                {
                    # Send the current page in the slideshow.
                    $page_to_load = $cur_page;
                }
                else
                {
                    # Check whether a static file by the requested name
                    # exists.  If so, send it.
                    for my $file (@{$self->{static_files}})
                    {
                        if ($file->pagename() eq $url)
                        {
                            $page_to_load = $file;
                            last;
                        }
                    }
                }

                if (defined($page_to_load))
                {
                    my $resp_page = $cache->get_page($page_to_load);
                    if (defined($resp_page))
                    {
                        my $len = length($resp_page);
                        say "Response: full page ($len characters)";
                        my $response = HTTP::Response->new();
                        $response->code(HTTP::Status::HTTP_OK);
                        $response->content($resp_page);
                        $response->header('Connection' => 'close');
                        $c->send_response($response);
                    }
                    else
                    {
                        say 'Response: 404 (non-existent page)';
                        $c->send_error(HTTP::Status::HTTP_NOT_FOUND);
                    }
                }
                else
                {
                    say 'Response: 404 (bad path)';
                    $c->send_error(HTTP::Status::HTTP_NOT_FOUND);
                }
            }
            else
            {
                say 'Response: 405 (not a GET request)';
                $c->send_error(HTTP::Status::HTTP_METHOD_NOT_ALLOWED);
            }
        }

        say 'Closing connection';
        $c->close();
        undef $c;
    }

    say 'Shutting down';
}

sub _load_file_lists
{
    my ($self, $exclude_ref) = @_;

    my $tmpl_dir = Flowcase::get_instance()->tmpl_dir();
    my $file_spec = "$tmpl_dir/*";
    my @files = File::Glob::glob($file_spec);
    my @errors;
    $self->{page_files} = [];
    $self->{static_files} = [];
    for my $file (@files)
    {
        given($file)
        {
            when (m|/([^/_]*)\.tmpl|)
            {
                my $pagename = $1;

                # Work-around for Perl bug #94682, which breaks the ability to
                # use $_ inside a given/when clause.  I decided to rewrite
                # List::MoreUtils::any() here so that I didn't have to require
                # users to use Perl 5.15.3, in which that bug is fixed.
                my $excluded = 0;
                for my $exclude_file (@$exclude_ref)
                {
                    if ($pagename eq $exclude_file)
                    {
                        $excluded = 1;
                        last;
                    }
                }

                if (!$excluded)
                {
                    my $o = Flowcase::PageFile->new
                    (
                        filename => $file,
                        pagename => $pagename,
                    );
                    push(@{$self->{page_files}}, $o);
                }
            }
            when (m|/(_[^/]*)$| && !m|\.tmpl$|)
            {
                my $o = Flowcase::PageFile->new
                (
                    filename => $file,
                    pagename => $1,
                );
                push(@{$self->{static_files}}, $o);
            }
            when (m|_[^/]*\.tmpl$|)
            {
                # No op.  These files are used internally as TT include
                # files.
            }
            default
            {
                push(@errors, $file);
            }
        }
    }

    say 'Page files: ', join(q{, }, @{$self->{page_files}});
    say 'Static files: ', join(q{, }, @{$self->{static_files}});

    return \@errors;
}

sub _start_server
{
    my $flowcase = Flowcase::get_instance();

    my $server = HTTP::Daemon->new
    (
        LocalAddr => $flowcase->listen_address(),
        LocalPort => $flowcase->listen_port(),
        Timeout   => ACCEPT_TIMEOUT,
    ) || die 'Unable to open listen port';

    return $server;
}

1;

