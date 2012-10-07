package Plack::Middleware::Xslate;
use strict;
use warnings;

use base 'Plack::Middleware::Static';

use Plack::Util::Accessor 'xslate_args', 'xslate_vars';

use Text::Xslate;

sub prepare_app {
    my $self = shift;
    $self->{file} = Plack::App::File::Xslate->new({ root => $self->root || '.', encoding => $self->encoding, xslate_args => $self->xslate_args, xslate_vars => $self->xslate_vars });
    $self->{file}->prepare_app;
}

# XXX copied and pasted from Plack::Middleware::Static just so i can override
# with Plack::App::File::Xslate instead of Plack::App::File - submit a patch
# upstream to make this more configurable
sub _handle_static {
    my($self, $env) = @_;

    my $path_match = $self->path or return;
    my $path = $env->{PATH_INFO};

    for ($path) {
        my $matched = 'CODE' eq ref $path_match ? $path_match->($_) : $_ =~ $path_match;
        return unless $matched;
    }

    local $env->{PATH_INFO} = $path; # rewrite PATH
    return $self->{file}->call($env);
}

package # hide from PAUSE
    Plack::App::File::Xslate;
use strict;
use warnings;

use base 'Plack::App::File';

use Plack::Util::Accessor 'xslate_args', 'xslate_vars';

use File::Spec;
use Cwd 'cwd';

sub prepare_app {
    my $self = shift;

    $self->SUPER::prepare_app(@_);

    $self->content_type('text/html');

    $self->xslate_args({
        %{ $self->xslate_args || {} },
        path => [ $self->root ],
    });
    $self->{xslate} = Text::Xslate->new($self->xslate_args || ());
}

sub serve_path {
    my $self = shift;
    my ($env, $file) = @_;

    my $res = $self->SUPER::serve_path(@_);

    my $filename = $res->[2]->path;
    if (File::Spec->file_name_is_absolute($filename)) {
        $filename = File::Spec->abs2rel($filename, $self->root);
    }

    my $rendered = $self->{xslate}->render($filename, $self->xslate_vars);

    $res->[2] = [ $rendered ];

    return $res;
}

1;
