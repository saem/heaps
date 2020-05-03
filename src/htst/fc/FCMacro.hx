package htst.fc;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.Tools;

class FCMacro {
    public static function forAllExpressionBuild():ComplexType {
        return switch(Context.getLocalType()) {
            case TInst(_.get() => {name: "ForAllExpression"}, params):
                return buildForAllClass(params);
            default:
                throw "Failed to build forAllExpression";
        }
    }

    static function buildForAllClass(params:Array<Type>): ComplexType {
        final numParams = params.length;
        final name = 'ForAllExpression$numParams';
        final pack = ["htst", "fc"];
        final ctParams: Array<TypeParam> = [for (t in params) TPType(t.toComplexType())];

        if(doesTypeExist(name)) {
            return TPath({pack: pack, name: name, params: ctParams});
        }

        final typeParams:Array<TypeParamDecl> = [];
        final superClassFunctionArgs:Array<ComplexType> = [];
        final arbitraryArgs:Array<FunctionArg> = [];
        
        for(i in 0...numParams) {
            typeParams.push({name: 'T$i'});
            superClassFunctionArgs.push(TPath({name: 'T$i', pack: []}));
        }

        final pos = Context.currentPos();
        Context.defineType({
            pack: pack,
            name: name,
            pos: pos,
            params: typeParams,
            kind: TDClass({
                pack: pack,
                name: "ForAllExpression",
                params: []
            }),
            fields: []
        });

        return TPath({pack: pack, name: name, params: ctParams});
    }

    static function doesTypeExist(typeName:String):Bool {
        return try { Context.getType(typeName) != null; }
            catch (error: String) false;
    }
}
#end