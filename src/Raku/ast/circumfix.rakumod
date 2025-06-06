# Marker for all kinds of circumfix.
class RakuAST::Circumfix
  is RakuAST::Term
  is RakuAST::Contextualizable { }

# Grouping parentheses circumfix.
class RakuAST::Circumfix::Parentheses
  is RakuAST::Circumfix
{
    has RakuAST::SemiList $.semilist;

    method new(RakuAST::SemiList $semilist) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Circumfix::Parentheses, '$!semilist', $semilist);
        $obj
    }

    method PERFORM-CHECK(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        # Avoid worries about sink context since parentheses may just be used
        # for syntactic grouping. Unless it's an empty list, then there's no one
        # else to blame.
        self.add-sunk-worry($resolver, self.origin ?? self.origin.Str !! self.DEPARSE)
            if self.sunk && $!semilist.is-empty;
    }

    # Generally needs to be called before children are visited, which is when the Apply*
    # expressions implement their currying. After that happens, any RakuAST::Term::Whatever
    # operands will have been converted to RakuAST::Var::Lexical. At that stage, the below
    # IMPL-SINGLE-CURRIED-EXPRESSION is the appropriate check.
    method IMPL-CONTAINS-SINGULAR-CURRYABLE-EXPRESSION() {
        nqp::elems($!semilist.IMPL-UNWRAP-LIST($!semilist.statements)) == 1
            && (my $statement-expression := $!semilist.IMPL-UNWRAP-LIST($!semilist.statements)[0])
            && nqp::istype($statement-expression, RakuAST::Statement::Expression)
            && (my $expression := $statement-expression.expression)
            && nqp::istype($expression, RakuAST::WhateverApplicable)
            && $expression.IMPL-SHOULD-CURRY-DIRECTLY
                ?? $expression
                !! Nil
    }

    method IMPL-SINGULAR-CURRIED-EXPRESSION() {
        nqp::elems($!semilist.IMPL-UNWRAP-LIST($!semilist.statements)) == 1
            && (my $statement-expression := $!semilist.IMPL-UNWRAP-LIST($!semilist.statements)[0])
            && nqp::istype($statement-expression, RakuAST::Statement::Expression)
            && (my $expression := $statement-expression.expression)
            && nqp::istype($expression, RakuAST::WhateverApplicable)
            && $expression.IMPL-CURRIED
                ?? $expression
                !! Nil
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        # QAST::Stmts node needed to e.g. break up operator chaining
        QAST::Stmts.new($!semilist.IMPL-TO-QAST($context))
    }

    method visit-children(Code $visitor) {
        $visitor($!semilist);
    }

    method IMPL-IS-CONSTANT() {
        my $statements := $!semilist.IMPL-UNWRAP-LIST($!semilist.statements);
        for $statements {
            if nqp::istype($_, RakuAST::Statement::Expression) {
                return False unless $_.expression.IMPL-IS-CONSTANT;
            }
            else {
                return False;
            }
        }
        True
    }

    method has-compile-time-value() {
        $!semilist.has-compile-time-value;
    }

    method maybe-compile-time-value() {
        $!semilist.maybe-compile-time-value;
    }

    method IMPL-CAN-INTERPRET() {
        $!semilist.IMPL-CAN-INTERPRET
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        $!semilist.IMPL-INTERPRET($ctx)
    }
}

class RakuAST::Exception::TooComplex {
    has Str $.name;
    method new() {
        nqp::create(self)
    }
    method set-name($name) {
        nqp::bindattr(self, RakuAST::Exception::TooComplex, '$!name', $name);
    }
    method throw() {
        my $ex := nqp::newexception();
        nqp::setpayload($ex, self);
        nqp::throw($ex);
    }
}

# Array composer circumfix.
class RakuAST::Circumfix::ArrayComposer
  is RakuAST::Circumfix
  is RakuAST::Lookup
  is RakuAST::ParseTime
  is RakuAST::CheckTime
  is RakuAST::ColonPairish
{
    has RakuAST::SemiList $.semilist;

    method new(RakuAST::SemiList $semilist) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Circumfix::ArrayComposer, '$!semilist', $semilist);
        $obj
    }

    method canonicalize() {
        my @statements := self.semilist.code-statements;
        if nqp::elems(@statements) == 1 && @statements[0].expression.IMPL-CAN-INTERPRET {
            self.IMPL-QUOTE-VALUE(@statements[0].expression.IMPL-INTERPRET(RakuAST::IMPL::InterpContext.new))
        }
        else {
            my @parts;
            for @statements {
                nqp::die('canonicalize NYI for non-simple colonpairs: ' ~ $_.HOW.name($_))
                    unless nqp::istype($_, RakuAST::Statement::Expression);
                RakuAST::Exception::TooComplex.new.throw unless nqp::can($_.expression, 'literal-value');
                nqp::push(@parts, "'" ~ $_.expression.literal-value ~ "'");
            }
            @parts ?? '[' ~ nqp::join('; ', @parts) ~ ']' !! '<>'
        }
    }

    method PERFORM-PARSE(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        my $resolved := $resolver.resolve-lexical('&circumfix:<[ ]>');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    # Second chance to resolve operators in the setting
    method PERFORM-CHECK(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        unless self.is-resolved {
            my $resolved := $resolver.resolve-lexical('&circumfix:<[ ]>');
            if $resolved {
                self.set-resolution($resolved);
            }
        }
        True
    }


    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        my $name := self.resolution.lexical-name;
        QAST::Op.new(
            :op('call'), :$name,
            $!semilist.IMPL-TO-QAST($context)
        )
    }

    method visit-children(Code $visitor) {
        $visitor($!semilist);
    }

    method IMPL-CAN-INTERPRET() {
        my @statements := self.semilist.code-statements;
        nqp::elems(@statements) == 1 && @statements[0].IMPL-CAN-INTERPRET
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        my @statements := self.semilist.code-statements;
        my $result := @statements[0].IMPL-INTERPRET($ctx);
        Array.new($result)
    }
}

# Hash composer circumfix. In Raku syntax, blocks and hash composers are
# distinguished based upon a number of criteria, applied after parsing the
# thing as a block. At the AST level there are two distinct node types:
# this, and Block (for the case it's a block). The Block node has a method
# on it for performing this disambiguation.
class RakuAST::Circumfix::HashComposer
  is RakuAST::Circumfix
  is RakuAST::Lookup
  is RakuAST::ParseTime
  is RakuAST::CheckTime
{
    has RakuAST::Expression $.expression;
    has int $.object-hash;

    method new(RakuAST::Expression $expression?, int :$object-hash) {
        my $obj := nqp::create(self);
        $obj.set-expression($expression);
        nqp::bindattr_i($obj, RakuAST::Circumfix::HashComposer, '$!object-hash', $object-hash ?? 1 !! 0);
        $obj
    }

    method set-expression(RakuAST::Expression $expression) {
        nqp::bindattr(self, RakuAST::Circumfix::HashComposer, '$!expression',
            $expression // RakuAST::Expression);
        Nil
    }

    method PERFORM-PARSE(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        my $resolved := $!object-hash
                             ?? $resolver.resolve-lexical('&circumfix:<:{ }>')
                             !! $resolver.resolve-lexical('&circumfix:<{ }>');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    # Second chance to resolve operators in the setting
    method PERFORM-CHECK(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        unless self.is-resolved {
            my $resolved := $resolver.resolve-lexical($!object-hash ?? '&circumfix:<:{ }>' !! '&circumfix:<{ }>');
            if $resolved {
                self.set-resolution($resolved);
            }
        }
        True
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        my $name := self.resolution.lexical-name;
        my $expression := $!expression;

        my $op := QAST::Op.new(:op<call>, :$name);
        if $expression {
            $op.push($expression.IMPL-TO-QAST($context))
        }
        $op
    }

    method visit-children(Code $visitor) {
        $visitor($!expression) if $!expression;
    }
}
