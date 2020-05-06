package htst.fc;

#if macro
import haxe.macro.Expr;
import haxe.macro.Expr.ExprDef;
import haxe.macro.Context;
import haxe.macro.Expr.Position;

class FCMacroTools {
    /**
        Lifted from tink_macro library, see Exprs.hx
    **/
    public static function atPos(e:ExprDef, ?pos:Position): Expr {
        return { expr: e, pos: pos == null ? Context.currentPos() : pos };
    }

    /**
        Lifted from tink_macro library, see Exprs.hx
    **/
    public static function concat(e:Expr, with:Expr, ?pos): Expr {
        if(pos == null) pos = e.pos;
        return switch [e.expr, with.expr] {
            case [EBlock(e1), EBlock(e2)]: atPos(EBlock(e1.concat(e2)), pos);
            case [EBlock(e1), e2]: atPos(EBlock(e1.concat([with])), pos);
            case [e1, EBlock(e2)]: atPos(EBlock([e].concat(e2)), pos);
            default: atPos(EBlock([e, with]), pos);
        }
    }
}
#end