# shorthand for loading Telemetry and starting a snapper

use Telemetry;

snapper( %*ENV<SNAPPER> // 0.1 );

# vim: ft=perl6 expandtab sw=4