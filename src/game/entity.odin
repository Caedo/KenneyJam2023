package game

import dm "../dmcore"
import "../dmcore/globals"
import "core:fmt"

import "core:math/ease"

import "core:math/linalg/glsl"

EntityHandle :: distinct dm.Handle

EntityFlag :: enum {

}

ControlerType :: enum {
    None,
    Player,
}

Entity :: struct {
    handle: EntityHandle, // @TODO: do I need it..?
    flags: bit_set[EntityFlag],

    controler: ControlerType,

    position: dm.iv2,

    sprite: dm.Sprite,
    tint: dm.color,
}

CreateEntityHandle :: proc() -> EntityHandle {
    return cast(EntityHandle) dm.CreateHandle(gameState.entities)
}

CreateEntity :: proc() -> ^Entity {
    handle := CreateEntityHandle()
    assert(handle.index != 0)

    entity := dm.GetElement(gameState.entities, dm.Handle(handle))

    entity.handle = handle
    entity.tint = dm.WHITE

    return entity
}

////////////

ControlEntity :: proc(entity: ^Entity) {
    switch(entity.controler) {
        case .Player: ControlPlayer(entity)
        case .None: // ignore
    }
}


////////////

CreatePlayerEntity :: proc() -> EntityHandle {
    player := CreateEntity()

    player.controler = .Player
    player.sprite = dm.CreateSprite(gameState.atlas, {0, 0, 16, 16})

    return player.handle
}


ControlPlayer :: proc(player: ^Entity) {
    player.position.x += dm.GetAxisInt(globals.input, .Left, .Right, .JustPressed)
    player.position.y += dm.GetAxisInt(globals.input, .Down, .Up, .JustPressed)
}