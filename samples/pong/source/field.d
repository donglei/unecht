﻿module field;

import unecht;

///
final class Field : UEComponent
{
    mixin(UERegisterObject!());
    
    static immutable x = 15;
    static immutable z = 10;
    static immutable h = 2;

    private UEEntity borderLeft;
    
    override void onCreate() {
        super.onCreate;
        

        createBorder(false, vec3(0,h/2,-z), vec3(x,h,1));
        createBorder(false, vec3(0,h/2,z), vec3(x,h,1));
        createBorder(true, vec3(-x-1.1f,h/2,0), vec3(1,h,z));
        borderLeft = createBorder(true, vec3(x+1.1f,h/2,0), vec3(1,h,z));
    }
    
    UEEntity createBorder(bool _outside, vec3 _pos, vec3 _size)
    {
        auto name = "border";
        if(_outside)
            name ~="-out";
        
        auto newE = UEEntity.create(name,sceneNode);
        newE.sceneNode.position = _pos;
        newE.sceneNode.scaling = _size;
        auto shape = newE.addComponent!UEShapeBox;
        newE.addComponent!UEPhysicsColliderBox;
        if(!_outside)
        {
            newE.getComponent!(UEMaterial).uniforms.setColor(vec4(0,1,0,1));
            
            auto material = newE.addComponent!UEPhysicsMaterial;
            material.materialInfo.bouncyness = 1.0f;
            material.materialInfo.friction = 0;
        }

        return newE;
    }

    bool isLeft(UEEntity entity)
    {
        return entity is borderLeft;
    }
}