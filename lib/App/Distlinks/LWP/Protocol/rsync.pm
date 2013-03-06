# Copyright 2012, 2013 Kevin Ryde

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


# require App::Distlinks::LWP::Protocol::rsync;
# LWP::Protocol::implementor('rsync', 'App::Distlinks::LWP::Protocol::rsync');
#
# cf LWP::Protocol::file


package App::Distlinks::LWP::Protocol::rsync;
use strict;
use HTTP::Date;
use HTTP::Response;
use HTTP::Status;

use vars '$VERSION','@ISA';
$VERSION = 9;

use LWP::Protocol;
@ISA = qw(LWP::Protocol);

# uncomment this to run the ### lines
#use Smart::Comments;




sub request {
  my($self, $request, $proxy, $arg, $size) = @_;

  $size = 4096 unless defined $size and $size > 0;

  if (defined $proxy) {
    return HTTP::Response->new(HTTP::Status::RC_BAD_REQUEST(),
                               'No proxy for rsync');
  }

  my $method = $request->method;
  ### $method
  unless ($method eq 'GET' || $method eq 'HEAD') {
    return HTTP::Response->new(HTTP::Status::RC_BAD_REQUEST(),
                               "Method \"$method\" not supported for rsync");
  }

  # URI::rsync documented in URI.pm
  my $url = $request->uri;

  my $scheme = $url->scheme;
  if ($scheme ne 'rsync') {
    return HTTP::Response->new(HTTP::Status::RC_INTERNAL_SERVER_ERROR(),
                               "Oops, uri scheme not rsync");
  }

  # my $ims = $request->header('If-Modified-Since');

  require File::Temp;
  my $fh = File::Temp->new;
  binmode($fh)
    or return HTTP::Response->new(HTTP::Status::RC_INTERNAL_SERVER_ERROR(),
                                  'Oops, cannot binmode on tempfile');
  my $filename = $fh->filename;
  ### $filename

  my $errfh = File::Temp->new;
  my $errfilename = $errfh->filename;
  ### $errfilename

  my @run3_args;
  if ($method eq 'HEAD') {
    @run3_args = (['rsync',
                   '-t', # set $filename modtime
                   $url,
                  ],
                  \undef,
                  $filename,
                  $errfilename);
  } else {
    @run3_args = (['rsync',
                   '-t', # set $filename modtime
                   $url,
                   $filename],
                  \undef,
                  $errfilename,
                  $errfilename,
                  { append_stdout => 1,
                    append_stderr => 1 });
  }

  require IPC::Run3;
  if (! eval { IPC::Run3::run3(@run3_args) }) {
    my $err = $@;
    return HTTP::Response->new(HTTP::Status::RC_INTERNAL_SERVER_ERROR(),
                               "Cannot run rsync program: $err");
  }
  my $wstat = $?;
  ### $wstat

  ### ls: system("ls -l $filename")
  ### ls: system("ls -l $errfilename")

  if ($wstat != 0) {
    my $err = "rsync error waitstatus=$wstat";
    require Perl6::Slurp;
    my $errout = Perl6::Slurp::slurp ($errfilename);
    if ($errout ne '') {
      $err .= "\n$errout";
    }
    return HTTP::Response->new(HTTP::Status::RC_NOT_FOUND(), $err);
  }

  my $response = HTTP::Response->new(HTTP::Status::RC_OK());

  if ($method eq 'HEAD') {
    require Perl6::Slurp;
    my $listing = Perl6::Slurp::slurp ($filename);
    # -rw-r--r--        1260 2004/10/29 04:50:12 foo.txt
    if ($listing =~ /(\d+)/) {
      $response->header('Content-Length', $1);
    }
    if ($listing =~ m{\d+ ([0-9/]+ [0-9:]+)}) {
      if (defined (my $mtime = HTTP::Date::str2time($1))) {
        $response->header('Last-Modified', HTTP::Date::time2str($mtime));
      }
    }

  } else {
    # $method eq 'GET'

    # can't use $fh, rsync seems to replace the target file

    $response->header('Content-Length', -s $filename);
    {
      my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$filesize,
         $atime,$mtime,$ctime,$blksize,$blocks)
        = stat $filename;
      ### $mtime
      $response->header('Last-Modified', HTTP::Date::time2str($mtime));
    }

    open my $readfh, $filename
      or return HTTP::Response->new(HTTP::Status::RC_INTERNAL_SERVER_ERROR(),
                                    "Cannot open tempfile: $!");
    {
      my $readerr;
      $response = $self->collect($arg, $response, sub {
                                   my $content = "";
                                   my $bytes = sysread($readfh, $content, $size);
                                   ### $bytes
                                   if (! defined $bytes) {
                                     $readerr = "$!";
                                   }
                                   return \$content;
                                 });
      if (defined $readerr) {
        return HTTP::Response->new(HTTP::Status::RC_INTERNAL_SERVER_ERROR(),
                                   "Error reading tempfile: $readerr");
      }
    }
    close $readfh
      or return HTTP::Response->new(HTTP::Status::RC_INTERNAL_SERVER_ERROR(),
                                    "Error reading tempfile: $!");
  }
  return $response;
}

1;
__END__
