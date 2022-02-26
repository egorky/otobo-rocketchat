# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::RocketChat::Util;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsNumber);

use Exporter qw(import);
our %EXPORT_TAGS = (    ## no critic
    all => [
      'GENERAL_CONFIG',
      'WEBSERVICE_CONFIG',
      'IsExtensionActive',
    ],
);
Exporter::export_ok_tags('all');

=encoding utf-8

=head1 NAME

C<Kernel::System::RocketChat::Util> - Configuration independent Helper
functions for Rocket.Chat Extension Modules

=head1 DESCRIPTION

This module contains helpers and static values to be used by other modules of
the Rocket.Chat extension. In contrast to C<Kernel::System::RocketChat> it can
always be imported regardless of the current configuration state.

=cut

=head1 PUBLIC INTERFACE

=head2 Configuration Constants

C<Kernel::System::RocketChat::Util> exposes the following constants containing
the name of module related settings:

=over

=item *
C<GENERAL_CONFIG>

=item *
C<WEBSERVICE_CONFIG>

=back

=cut

use constant {
  GENERAL_CONFIG => 'Core::RocketChat###0001-General',
  WEBSERVICE_CONFIG => 'Core::RocketChat###0010-Webservice',
};

=head2 IsExtensionActive()

C<IsExtensionActive()> checks - provided a C<SysConfigObject> - if the
Rocket.Chat extension is currently active. This is determined by the following
conditions:

=over

=item *
C<GENERAL_CONFIG> is valid

=item *
C<WEBSERVICE_CONFIG> is valid

=item *
C<WEBSERVICE_CONFIG> has C<WebserviceID> set

=back

If C<IsExtensionActive()> returns 1, the following B<should> be true:

=over

=item *
The extension has been activated and properly configured by an admin

=item *
C<WebserviceID> is the ID of a valid Webservice usable to contact the
Rocket.Chat API.

=back

Note that these points B<should> only be the case, but are not B<guaranteed> by
C<IsExtensionActive()>, i. e. it does not check if the Webservice exists.
B<Should> means that it is the case if the Rocket.Chat Extension's configuration
interface has been used as intended. With the nature of OTOBO however, someone
could have tampered with the configuration afterwards, rendering our assumptions wrong.

Example usage:

    my $IsActive = IsExtensionActive(
        SysConfigObject => $SysConfigObject
    );

Return value: C<0> or C<1>

=cut

sub IsExtensionActive {
  my (%Params) = @_;

  unless($Params{SysConfigObject}) {
    return 0;
  }

  my %GeneralConfig = $Params{SysConfigObject}->SettingGet(
    Name => GENERAL_CONFIG,
  );

  my %WebserviceConfig = $Params{SysConfigObject}->SettingGet(
    Name => WEBSERVICE_CONFIG,
  );

  return ($GeneralConfig{IsValid} && $WebserviceConfig{IsValid} &&
          IsNumber($WebserviceConfig{EffectiveValue}->{WebserviceID}));
}

1;
