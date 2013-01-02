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

package Flowcase::Pages::Weather;

use common::sense;

use JSON::PP;
use LWP::UserAgent;
use Moose;

has 'apikey' => (is => 'ro', isa => 'Str');
has 'place' => (is => 'ro', isa => 'Str');

sub BUILD
{
    my ($self) = @_;

    $self->{ua} = LWP::UserAgent->new();
    $self->{json} = JSON::PP->new();
}

sub cache_ttl { 240 };

sub get_vars
{
    my ($self) = @_;

    return { %{$self->_get_forecast_vars()},
             %{$self->_get_conditions_vars()} };
}

sub get_url
{
    my ($self, $url) = @_;
    say "Getting URL [$url]";
    my $response = $self->{ua}->get($url);
    return $response->is_success() ?
           $response->decoded_content() :
           undef;
}

sub _get_forecast_vars
{
    my ($self) = @_;

    my $url = 'http://api.wunderground.com/' .
              'api/' . $self->{apikey} . '/' .
              "forecast/q/$self->{place}.json";
    my $json = $self->get_url($url);

    my $forecast = $self->{json}->decode($json);
    my $days = $forecast->{forecast}->{simpleforecast}->{forecastday};

    my %vars = (days => []);
    my $count = 0;
    for my $day (@$days)
    {
        push(@{$vars{days}},
        {
            weekday => $day->{date}->{weekday},
            weather => $day->{conditions},
            high    => $day->{high}->{fahrenheit},
            low     => $day->{low}->{fahrenheit},
        });

        last if ++$count >= 4;
    }

    return \%vars;
}

sub _get_conditions_vars
{
    my ($self) = @_;

    my $url = 'http://api.wunderground.com/' .
              'api/' . $self->{apikey} . '/' .
              "conditions/q/$self->{place}.json";
    my $json = $self->get_url($url);

    my $weather = $self->{json}->decode($json);
    my $cur = $weather->{current_observation};

    my %vars =
    (
        feels_like    => $cur->{feelslike_f},
        humidity      => $cur->{relative_humidity},
        location      => $cur->{display_location}->{full},
        temperature   => $cur->{temp_f},
        weather       => $cur->{weather},
        wind_dir      => $cur->{wind_dir},
        wind_gust_mph => sprintf('%.1f', $cur->{wind_gust_mph}),
        wind_mph      => sprintf('%.1f', $cur->{wind_mph}),
    );

    return \%vars;
}

1;
