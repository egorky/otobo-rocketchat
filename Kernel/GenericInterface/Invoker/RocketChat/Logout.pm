# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::Logout;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData);

our $ObjectManagerDisabled = 1;

sub new {
  my ($Type, %Param) = @_;

  my $Self = {};

  bless($Self, $Type);

  if(!$Param{DebuggerObject}) {
    return {
      Success => 0,
      ErrorMessage => "Got no DebuggerObject",
    };
  }

  $Self->{DebuggerObject} = $Param{DebuggerObject};

  return $Self;
}

sub PrepareRequest {
  my ($Self, %Param) = @_;

  return {
    Success => 1,
    Data => {
      # send some garbage since it is not possible to send an empty body
      # using HTTP::REST with POST at the moment.
      # See: https://github.com/OTRS/otrs/pull/2028
      bogus => 'value',
    },
  };
}

sub HandleResponse {
  my ($Self, %Param) = @_;

  if(!$Param{ResponseSuccess}) {
    # pass through error
    if(!IsStringWithData($Param{ResponseErrorMessage})) {
      return $Self->{DebuggerObject}->Error(
        Summary => 'Got response error, no message given',
      );
    }

    return {
      Success => 0,
      ErrorMessage => $Param{ResponseErrorMessage}
    };
  }

  if(IsStringWithData($Param{Data}->{'status'}) &&
    $Param{Data}->{'status'} eq 'success') {
    return {
      Success => 1,
      Data => undef,
    };
  } else {
    return $Self->{DebuggerObject}->Error(
      Summary => 'API did not return success',
      Data => {
        Message => $Param{Data}->{'data'}->{'message'},
      },
    );
  }
}

1;
