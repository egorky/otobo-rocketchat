# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::Lookup;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsArrayRefWithData IsNumber);

our $ObjectManagerDisabled = 1;

=encoding utf-8

=head1 NAME

C<Kernel::GenericInterface::Invoker::RocketChat::Lookup>

=head1 DESCRIPTION

Constructs a Request to Rocket.Chat's
L</api/v1/users.list|https://docs.rocket.chat/api/rest-api/methods/users/list>
endpoint that performs a search for users that have one of the given email addresses
associated with them.

=head1 PUBLIC INTERFACE

The C<Lookup> Invoker should be used via L<Lookup()|Kernel::System::RocketChat/Lookup>.

=cut

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

  $Self->{RC} = $Kernel::OM->Get('Kernel::System::RocketChat');

  return $Self;
}

=head1 INTERNALS

=head2 PrepareRequest()

Since the Request to perform is using C<GET>, C<PrepareRequest()> needs to
populate the two parameters C<fields> and C<query>. Both of those require
JSON encoding which is not handled by L<Kernel::GenericInterface::Transport::HTTP::REST>.
Therefore it uses L<Kernel::System::JSON> to do that.

For documentation of the query field's syntax refer to the
L<MongoDB Documentation|https://docs.mongodb.com/manual/reference/operator/query/>
=cut

sub PrepareRequest {
  my ($Self, %Param) = @_;

  my $Request;

  if(!IsArrayRefWithData($Param{Data}->{Emails}) || @{$Param{Data}->{Emails}} <= 0) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Got no Email address array which is required for lookup action"
    );
  } else {
    foreach my $Email (@{$Param{Data}->{Emails}}) {
      if(!IsStringWithData($Email) || !$Self->{RC}->IsEmailAddress($Email)) {
        return $Self->{DebuggerObject}->Error(
          Summary => "Got invalid email address in given array",
          Data => $Email,
        );
      }
    }
  }

  my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

  $Request = {
    'fields' => $JSONObject->Encode(Data => { 'username' => 1 }),
    'query' => $JSONObject->Encode(Data=>{
      'emails' => {
        '$elemMatch' => {
          'address' => {
            '$in' => $Param{Data}->{Emails},
          }
        },
      },
    }),
  };

  return {
    Success => 1,
    Data => $Request,
  };
}

=head2 HandleResponse()

C<HandleResponse()> mainly checks if one or more users are returned and
deals with some quirkiness of L<Kernel::System::JSON> where JSON arrays
with a single element are decoded to a single string instead of an array
with a single element.

=cut

sub HandleResponse {
  my ($Self, %Param) = @_;

  # forward possible response error
  if(!$Param{ResponseSuccess}) {
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

  if(IsNumber($Param{Data}->{'count'})) {
    my @ResponseData;
    if($Param{Data}->{'count'} > 0) {
      if(IsArrayRefWithData($Param{Data}->{'users'})) {
        @ResponseData = @{$Param{Data}->{'users'}};
        # force array
        @ResponseData = [ @ResponseData ] if ref @ResponseData ne 'ARRAY';
      } else {
        return $Self->{DebuggerObject}->Error(
          Summary => 'Response field users of unexpected format'
        );
      }
    } else {
      @ResponseData = ();
    }

    return {
      Success => 1,
      Data => @ResponseData,
    };
  } else {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Response field count missing or malformed',
    );
  }
}

1;
