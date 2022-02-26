# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::Login;

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

  unless(IsStringWithData($Param{Data}->{Username})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Param Username missing or malformed",
    );
  }

  unless(IsStringWithData($Param{Data}->{Password})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Param Password missing or malformed",
    );
  }

  return {
    Success => 1,
    Data => {
      'user' => $Param{Data}->{Username},
      'password' => $Param{Data}->{Password},
    }
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
      ErrorMessage => $Param{ResponseErrorMessage},
    };
  }

  my $Credentials = {
    AuthToken => $Param{Data}->{'data'}->{'authToken'},
    UserID => $Param{Data}->{'data'}->{'userId'},
  };

  if(IsStringWithData($Credentials->{AuthToken})
    && IsStringWithData($Credentials->{UserID})) {
    return {
      Success => 1,
      Data => $Credentials,
    };
  } else {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Missing authToken or userId from response',
    );
  }
}

1;
