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

package Flowcase::PageCache;

use common::sense;

use Moose;
use Template;
use Template::Constants qw(:debug);

use Flowcase;

sub BUILD
{
    my ($self) = @_;

    $self->{template_processor} = Template->new
    (
        { INCLUDE_PATH => Flowcase::get_instance()->tmpl_dir() },
    );
    $self->{page_cache} = { };
}

sub get_page
{
    my ($self, $page_file) = @_;

    say "Handling page [$page_file]";

    my $filename = $page_file->filename();

    # Serve non-template files directly.
    if ($filename !~ /\.tmpl$/)
    {
        my $fh;
        if (!open($fh, '<', $filename))
        {
            say "Unable to open file [$filename]: $!";
            return undef;
        }
        my $content = q{};
        $content .= $_ while ($_ = <$fh>);
        close($fh);
        return $content;
    }

    my $page = $page_file->pagename();

    my $cached_text = $self->_get_cached_page($page);
    if (defined($cached_text))
    {
        say 'Using cached content';
        return $cached_text;
    }

    my $bare_module = $page_file->classname();
    my $module = $page_file->module();

    say "Loading module [$module]";
    eval "require $module";
    if ($@)
    {
        say "Unable to load module [$module]: $@";
        return undef;
    }

    my $config_ref = Flowcase::get_instance()->config();
    my %module_opts;
    for my $key (%$config_ref)
    {
        if ($key =~ /^$bare_module/)
        {
            my $value = $config_ref->{$key};
            $key =~ s/^.*?\.//;
            $module_opts{$key} = $value;
        }
    }
    my $obj;
    my $vars_ref;
    eval
    {
        $obj = "$module"->new(\%module_opts);
        $vars_ref = $obj->get_vars();
    };
    if ($@)
    {
        say "Unable to retrieve variables from module [$module]: $@";
        return undef;
    }

    $vars_ref->{flowcase} =
    {
        page_delay => Flowcase::get_instance()->page_delay(),
    };

    my $text = q{};
    my $template = $self->{template_processor};
    $template->process("$page.tmpl", $vars_ref, \$text);

    my $error = $template->error();
    if ($error)
    {
        say "TT ERROR: " . $error;
    }

    my $cache_ttl;
    eval
    {
        $cache_ttl = $obj->cache_ttl();
    };
    if ($@)
    {
        $cache_ttl = 0;
    }

    if ($cache_ttl > 0)
    {
        say "Caching page for [$cache_ttl] seconds";
        $self->_set_cached_page($page, $text, $cache_ttl);
    }

    return $text;
}

sub _get_cached_page
{
    my ($self, $page) = @_;

    my $cache = $self->{page_cache}->{$page};
    if ($cache)
    {
        if (time() > $cache->{cache_time} + $cache->{ttl})
        {
            # Value is expired; delete it.
            say "Deleting expired cache content for page [$page]";
            delete $self->{page_cache}->{$page};
            return undef;
        }

        return $cache->{content};
    }

    return undef;
}

sub _set_cached_page
{
    my ($self, $page, $content, $ttl) = @_;

    $self->{page_cache}->{$page} =
    {
        cache_time => time(),
        content => $content,
        ttl => $ttl,
    };
}

sub _is_valid_page
{
    my ($self, $page) = @_;

    my $flowcase = Flowcase::get_instance();
    my $tmpl_dir = $flowcase->tmpl_dir();
    my $tmpl_file = "$tmpl_dir/$page.tmpl";
    say "Checking for existence of file [$tmpl_file]";
    return -e $tmpl_file ? $tmpl_file : undef;
}

1;
