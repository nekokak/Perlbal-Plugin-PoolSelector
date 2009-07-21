package Perlbal::Plugin::PoolSelector;
use strict;
use warnings;

use URI::Escape;

our $VERSION = '0.01';

sub load {
    my $class = shift;

    Perlbal::register_global_hook('manage_command.pool_selector', sub {
        my $mc = shift->parse(qr/^pool_selector\s+(?:(\w+)\s+)?(\S+)\s*=\s*(\S+)$/,
                              "usage: POOL_SELECTOR [<service>] <uri_regex> = <pool_name>");
        my ($selname, $regex, $pool_name) = $mc->args;

        unless ($selname ||= $mc->{ctx}{last_created}) {
            return $mc->err("omitted service name not implied from context");
        }

        my $ss = Perlbal->service($selname);
        return $mc->err("Service '$selname' is not a reverse_proxy service")
            unless $ss && $ss->{role} eq "reverse_proxy";

        push(@{$ss->{extra_config}->{_poolselectors}}, [$regex, $pool_name]);

        return $mc->ok;
    });

    Perlbal::register_global_hook('manage_command.pool_default', sub {
        my $mc = shift->parse(qr/^pool_default\s+(\w+)$/,
                              "usage: POOL_DEFAULT <default_pool>");
        my ($default_pool,) = $mc->args;

        my $selname;
        unless ($selname ||= $mc->{ctx}{last_created}) {
            return $mc->err("omitted service name not implied from context");
        }

        my $ss = Perlbal->service($selname);
        return $mc->err("Service '$selname' is not a reverse_proxy service")
            unless $ss && $ss->{role} eq "reverse_proxy";

        $ss->{extra_config}->{_poolselector_default} = $default_pool;
        return $mc->ok;
    });

    return 1;
}

sub register {
    my ($class, $svc) = @_;
    unless ($svc && $svc->{role} eq "reverse_proxy") {
        die "You can't load the pool_selector plugin on a service not of role reverse_proxy.\n";
    }

    $svc->register_hook(
        PoolSelector => 'start_proxy_request', sub {
            my Perlbal::ClientProxy $client = shift;
            my $chk_uri = URI::Escape::uri_unescape($client->{req_headers}->{uri});
            # queryは無視
            $chk_uri =~ s/\?.+$//g;

            $svc->{pool} = '';
            for my $setting ( @{$svc->{extra_config}->{_poolselectors}} ) {
                my ($reg, $pool_name) = @{$setting};
                if ($chk_uri =~ /$reg/) {
                    my $pool = Perlbal->pool($pool_name);
                    $svc->{pool} = $pool;
                    last;
                }
            }
            unless ($svc->{pool}) {
                $svc->{pool} = Perlbal->pool($svc->{extra_config}->{_poolselector_default});
            }

            return 0;
        }
    );
    return 1;
}

1;

__END__

=head1 NAME

Perlbal::Plugin::PoolSelector - let URL match it in regular expression

=head1 SYNOPSIS

    in your perlbal.conf:

    LOAD PoolSelector
    CREATE SERVICE example
        SET role    = reverse_proxy
        SET plugins = PoolSelector
        POOL_DEFAULT app_pool
        POOL_SELECTOR /output/ = example_output_pool
        POOL_SELECTOR \.(jpg|gif|png|js|css|swf|ico|txt)$ = example_static_pool
    ENABLE example

=head1 DESCRIPTION

let URL match it in regular expression.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Atsushi Kobayashi  C<< <nekokak __at__ gmail.com> >>

=cut

