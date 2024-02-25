class Perl6::Metamodel::NativeHOW
    does Perl6::Metamodel::Naming
    does Perl6::Metamodel::Documenting
    does Perl6::Metamodel::Composing
    does Perl6::Metamodel::Versioning
    does Perl6::Metamodel::Stashing
    does Perl6::Metamodel::MultipleInheritance
    does Perl6::Metamodel::C3MRO
    does Perl6::Metamodel::MROBasedMethodDispatch
    does Perl6::Metamodel::MROBasedTypeChecking
{
    has     $!nativesize;   # XXX should probably be an int
    has int $!unsigned;

    my $archetypes := Perl6::Metamodel::Archetypes.new(:nominal);
    method archetypes($XXX?) { $archetypes }

    method new(*%named) {
        nqp::findmethod(NQPMu, 'BUILDALL')(nqp::create(self), %named)
    }

    method new_type(
      :$name = '<anon>',
      :$repr = 'P6opaque',
      :$ver,
      :$auth,
      :$api
    ) {
        my $HOW    := self.new;
        my $target := nqp::settypehll(nqp::newtype($HOW, $repr), 'Raku');

        $HOW.set_name($target, $name);
        $HOW.set_ver( $target, $ver);
        $HOW.set_auth($target, $auth) if $auth;
        $HOW.set_api( $target, $api)  if $api;
        $HOW.add_stash($target);
    }

    method compose($target, *%_) {
        $target := nqp::decont($target);

        self.compute_mro($target);
        self.publish_method_cache($target);
        self.publish_type_cache($target);

        if !self.is_composed && ($!nativesize || $!unsigned) {
            my $info := nqp::hash(
              'integer', nqp::hash('unsigned', $!unsigned),
              'float',   nqp::hash
            );

            # Specified using a native
            if nqp::objprimspec($!nativesize) {
                $info<integer><bits> :=
                $info<float><bits>   := $!nativesize;
            }

            # Actually specified with a HLL (hopefully Int) value
            elsif $!nativesize {
                $info<integer><bits> :=
                $info<float><bits>   := nqp::unbox_i($!nativesize);
            }

            nqp::composetype($target, $info);
        }
        self.set_composed;
    }

    my constant CTYPES := nqp::hash(
      'atomic',     nqp::const::C_TYPE_ATOMIC_INT,
      'bool',       nqp::const::C_TYPE_BOOL,
      'char',       nqp::const::C_TYPE_CHAR,
      'double',     nqp::const::C_TYPE_DOUBLE,
      'float',      nqp::const::C_TYPE_FLOAT,
      'int',        nqp::const::C_TYPE_INT,
      'long',       nqp::const::C_TYPE_LONG,
      'longdouble', nqp::const::C_TYPE_LONGDOUBLE,
      'longlong',   nqp::const::C_TYPE_LONGLONG,
      'short',      nqp::const::C_TYPE_SHORT,
      'size_t',     nqp::const::C_TYPE_SIZE_T,
    );
    method set_ctype($XXX, str $ctype) {
        $!nativesize := nqp::ifnull(
          nqp::atkey(CTYPES, $ctype),
          nqp::die("Unhandled C type '$ctype'")
        )
    }

    method set_nativesize($XXX, $nativesize) {
        $!nativesize := $nativesize;
    }
    method set_unsigned($XXX, $unsigned) {
        $!unsigned := $unsigned ?? 1 !! 0
    }

    method unsigned(  $XXX?) { $!unsigned   }
    method nativesize($XXX?) { $!nativesize }

    method method_table($XXX?) {
        nqp::hash('new',
          nqp::getstaticcode(sub (*@_, *%_) {
            nqp::die('Cannot instantiate a native type')
          }))
    }

    method submethod_table($XXX?) { nqp::hash }
}

# vim: expandtab sw=4
