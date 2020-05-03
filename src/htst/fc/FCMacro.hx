package htst.fc;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.Tools;

class FCMacro {
    static function forAllExpressionBuild():ComplexType {
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

        if(doesTypeExist(name)) {
            return TPath({pack: [], name: name, params: [for (t in params) TPType(t.toComplexType())]});
        }

        final typeParams:Array<TypeParamDecl> = [];
        final superClassFunctionArgs:Array<ComplexType> = [];
        final arbitraryArgs:Array<FunctionArg> = [];
        
        for(i in 0...numParams) {
            typeParams.push({name: 'T$i'});
            superClassFunctionArgs.push(TPath({name: 'T$i', pack: []}));
            d
        }

        return null;
    }

    static function doesTypeExist(typeName:String):Bool {
        return try { Context.getType(typeName) != null; }
            catch (error: String) false;
    }
}

#end