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
        final result = TPath({pack: pack, name: name, params: ctParams});

        if(doesTypeExist(name) || true) {
            return null;
        }

        final genType = Context.getType("htst.fc.Generator");
        final pos = Context.currentPos();

        final typeParams:Array<TypeParamDecl> = [];
        final superClassTypeParam:Array<ComplexType> = [];
        final dataTypeParams:Array<ComplexType> = [];
        final fields:Array<Field> = [];
        final genArgs:Array<FunctionArg> = [];
        final genSets:Array<Expr> = [];
        
        for(n in 0...numParams) {
            typeParams.push({name: 'T$n'});
            dataTypeParams.push(TPath({name: 'T$n', pack: []}));
            final genName = 'gen$n';
            final genType = TPath({name: "Generator", pack: pack, params: [ctParams[n]]});
            genArgs.push({
                name: genName, 
                type: genType,
                // TODO - support default generators based on type
                // opt: true,
                // value: null,
            });
            fields.push({name: genName, access:[APublic, AFinal], kind: FVar(genType), pos: pos});
            genSets.push(macro $p{["this", genName]} = $i{genName});
        }
        fields.push({
            name: "new",
            access: [APublic],
            pos: pos,
            kind: FFun({
                args: genArgs,
                expr: macro $b{genSets},
                ret: null,
            })
        });
        Context.defineType({
            pack: pack,
            name: name,
            pos: pos,
            params: typeParams,
            kind: TDClass({
                pack: pack,
                name: "ForAllExpression",
                sub: "ForAllExpressionBase",
                params: []
            }),
            fields: fields
        });

        return result;
    }

    static function doesTypeExist(typeName:String):Bool {
        return try { Context.getType(typeName) != null; }
            catch (error: String) false;
    }
}
#end