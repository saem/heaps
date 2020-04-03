
import hxd.Res;
import h3d.Vector;
import h3d.scene.*;
import h3d.scene.fwd.*;

class Helpers extends hxd.App {

	var time = 0.0;
	var cube : Mesh;
	var pointLights = new Array<PointLight>();

	override function init() {

		s3d.camera.pos.set( 5, 5, 5 );
		s3d.camera.setFovX( 70, s3d.camera.screenRatio );

		axesHelper( s3d );
		gridHelper( s3d, 10, 10 );

		var prim = new h3d.prim.Cube( 1, 1, 1, true );
		prim.unindex();
		prim.addNormals();
		prim.addUVs();

		cube = h3d.scene.Object.createMesh( prim, s3d );
		cube.setPosition( 0, 0, 2 );
		cube.material.shadows = false;

		axesHelper( cube, 1 );

		s3d.lightSystem.ambientLight.set( 0.3, 0.3, 0.3 );

		var dirLight = h3d.scene.Object.createFwdDirLight( new Vector( 0.5, 0.5, -0.5 ), s3d );
		dirLight.enableSpecular = true;

		var pointLightColors =  [0xEB304D,0x7FC309,0x288DF9];
		for( i in 0...pointLightColors.length ) {
			var l = h3d.scene.Object.createFwdPointLight( s3d );
			l.enableSpecular = true;
			l.color.setColor( pointLightColors[i] );
			pointLights.push( l );
			pointLightHelper( l );
		}

		this.s3d.createCameraController().loadFromCamera(this.s3d.camera);
	}

	override function update( dt : Float ) {

		time += dt;

		cube.rotate( 0.01, 0.02, 0.03 );

		pointLights[0].x = Math.sin( time ) * 3;
		pointLights[1].y = Math.sin( time ) * 3;
		pointLights[2].z = Math.sin( time ) * 3;
	}

	static function main() {
		Res.initEmbed();
		new Helpers();
	}

	static function axesHelper( ?parent : h3d.scene.Object, size = 2.0, colorX = 0xEB304D, colorY = 0x7FC309, colorZ = 0x288DF9, lineWidth = 2.0 ) {
		final g = h3d.scene.Object.createGraphics(parent);

		g.material.props = h3d.mat.MaterialSetup.current.getDefaults( "ui" );

		g.lineStyle(lineWidth);

		g.setColor( colorX );
		g.lineTo( size, 0, 0 );

		g.setColor( colorY );
		g.moveTo( 0, 0, 0 );
		g.lineTo( 0, size, 0 );

		g.setColor( colorZ );
		g.moveTo( 0, 0, 0 );
		g.lineTo( 0, 0, size );

		return g;
	}

	static function gridHelper( ?parent : Object, size = 10.0, divisions = 10, color1 = 0x444444, color2 = 0x888888, lineWidth = 1.0 ) {
		final g = h3d.scene.Object.createGraphics(parent);

		g.material.props = h3d.mat.MaterialSetup.current.getDefaults( "ui" );

		g.lineStyle(lineWidth);

		var hsize = size / 2;
		var csize = size / divisions;
		var center = divisions / 2;
		for( i in 0...divisions+1 ) {
			var p = i * csize;
			g.setColor( ( i!=0 && i!=divisions && i%center==0 ) ? color2 : color1 );
			g.moveTo( -hsize + p, -hsize, 0 );
			g.lineTo( -hsize + p, -hsize + size, 0 );
			g.moveTo( -hsize, -hsize + p, 0 );
			g.lineTo( -hsize + size, -hsize + p, 0 );
		}

		return g;
	}

	static function pointLightHelper( light : h3d.scene.fwd.PointLight, sphereSize = 0.5 ) {
		final prim = new h3d.prim.Sphere( sphereSize, 4, 2 );
		prim.addNormals();
		prim.addUVs();

		final m = h3d.scene.Object.createMesh(prim, light);
		m.material.color = light.color;
		m.material.mainPass.wireframe = true;

		return m;
	}
}