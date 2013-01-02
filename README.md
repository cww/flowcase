# Flowcase

Copyright 2012, 2013 Colin Wetherbee <cww@cpan.org>

Flowcase is a dynamic web page slideshow.

Using Perl and Template::Toolkit, you can create any dynamic content you want
and have it automatically refresh in a browser.  This is useful for hall
displays, conference kiosk boards, and any other context in which you might
have many different pieces of information to display, over time, to an
audience.

Flowcase was originally developed in order to display the current weather and
a stock market snapshot on a monitor in the author's home office, but it was
also designed to be scalable to serve any number of pages the user desires.

## Usage

For command-line options:

    Flowcase$ perl -Ilib bin/flowcase --help

Flowcase modules can be configured with `-c` options from the command line.
For example, in order to use the weather module, one must sign up for an API
key at wunderground.com and specify it, along with a latitude and longitude
(or another Weather Underground location identifier) on the command line:

    Flowcase$ perl -Ilib bin/flowcase -t ../pages \
        -c Weather.place=40.446808,-79.940140 -c Weather.apikey=abcdef01234
