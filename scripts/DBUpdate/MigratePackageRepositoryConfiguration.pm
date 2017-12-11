# --
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package scripts::DBUpdate::MigratePackageRepositoryConfiguration;    ## no critic

use strict;
use warnings;

use parent qw(scripts::DBUpdate::Base);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::SysConfig',
);

=head1 NAME

scripts::DBUpdateTo6::MigratePackageRepositoryConfiguration -  Migrate package repository configuration.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ConfigKey    = 'Package::RepositoryList';
    my %RepositoryList;
    if ( $ConfigObject->Get($ConfigKey) ) {
        %RepositoryList = %{ $ConfigObject->Get($ConfigKey) };
    }

    return 1 if !%RepositoryList;

    my @FrameworkVersionParts = split /\./, $ConfigObject->Get('Version');
    my $FrameworkVersion = $FrameworkVersionParts[0];

    my $CurrentITSMRepository = "http://ftp.otrs.org/pub/otrs/itsm/packages$FrameworkVersion/";

    return 1 if $RepositoryList{$CurrentITSMRepository};

    # Make sure ITSM repository matches the current framework version.
    my @Matches = grep { $_ =~ m{http://ftp\.otrs\.org/pub/otrs/itsm/packages\d+/}msxi } sort keys %RepositoryList;

    return 1 if !@Matches;

    # Delete all old ITSM repositories, but leave the current if exists
    for my $Repository (@Matches) {
        if ( $Repository ne $CurrentITSMRepository ) {
            delete $RepositoryList{$Repository};
        }
    }

    # Make sure that current ITSM repository is in the list
    $RepositoryList{$CurrentITSMRepository} = "OTRS::ITSM $FrameworkVersion Master";

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    my $ExclusiveLockGUID = $SysConfigObject->SettingLock(
        Name   => $ConfigKey,
        Force  => 1,
        UserID => 1,
    );

    my %Result = $SysConfigObject->SettingUpdate(
        Name              => $ConfigKey,
        IsValid           => 1,
        EffectiveValue    => \%RepositoryList,
        ExclusiveLockGUID => $ExclusiveLockGUID,
        UserID            => 1,
    );

    return if !$Result{Success};

    return 1;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
