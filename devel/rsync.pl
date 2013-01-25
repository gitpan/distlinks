#!/usr/bin/perl -w

# Copyright 2012 Kevin Ryde

# This file is part of Distlinks.
#
# Distlinks is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Distlinks is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with Distlinks.  If not, see <http://www.gnu.org/licenses/>.


# rsync --verbose --daemon --no-detach --config=rsyncd.conf

use strict;
use LWP::UserAgent;
use lib 'devel/lib';

require App::Distlinks::LWP::Protocol::rsync;
LWP::Protocol::implementor('rsync', 'App::Distlinks::LWP::Protocol::rsync');

{
  # my $url = 'rsync://download.tuxfamily.org/pub/user42/quick-yes.el';
  my $url = 'rsync://localhost:9999/top/etc/ucf.conf';

  my $ua = LWP::UserAgent->new;
  {
    my $resp = $ua->head($url);
    print "HEAD status_line: ",$resp->status_line,"<<<end\n";
    print $resp->as_string;
  }
  {
    my $resp = $ua->get($url);
    print "GET status_line: ",$resp->status_line,"<<<end\n";
    print $resp->as_string;
  }
  exit 0;
}
