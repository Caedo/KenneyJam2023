package game

import dm "../dmcore"
import "../dmcore/globals"
import "core:fmt"

import "core:math/ease"

import "core:math/linalg/glsl"

EntityHandle :: distinct dm.Handle

EntityFlag :: enum {
    HP,
    Pickup,
    Traversable,
    CanAttack,
}

ControlerType :: enum {
    None,
    Player,
}

Heading :: enum {
    None,
    North,
    South,
    West,
    East,
}

DirectionFromHeading := [Heading]dm.iv2 {
    .None  = {0,  0},
    .North = {0,  1},
    .South = {0, -1},
    .West  = {-1, 0},
    .East  = { 1, 0},
}

Entity :: struct {
    handle: EntityHandle, // @TODO: do I need it..?
    flags: bit_set[EntityFlag],

    controler: ControlerType,

    HP: int,

    goldValue: int,

    position: dm.iv2,
    direction: Heading,

    sprite: dm.Sprite,
    tint: dm.color,
}

Dir :: #force_inline proc(h: Heading) -> dm.iv2 {
    return DirectionFromHeading[h]
}

HeadingFromDir :: proc(dir: dm.iv2) -> Heading {
    if dir == {0,  1} do return .North
    if dir == {0, -1} do return .South
    if dir == {1,  0} do return .East
    if dir == {-1, 0} do return .West

    return .None
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

    entity.direction = .North

    return entity
}

DestroyEntity :: proc(handle: EntityHandle) {
    dm.FreeSlot(gameState.entities, auto_cast handle)
} 

////////////

ControlEntity :: proc(entity: ^Entity) {
    switch(entity.controler) {
        case .Player: ControlPlayer(entity)
        case .None: // ignore
    }
}


////////////

CreatePlayerEntity :: proc() -> ^Entity {
    player := CreateEntity()

    player.controler = .Player
    player.sprite = dm.CreateSprite(gameState.atlas, {0, 0, 16, 16})
    player.tint = PlayerColor

    player.flags = {.HP, .CanAttack, }

    player.position = {ChunkSize.x / 2, ChunkSize.y / 2}

    return player
}

ControlPlayer :: proc(player: ^Entity) {
    deltaMove: dm.iv2

    deltaMove.x = dm.GetAxisInt(globals.input, .Left, .Right, .JustPressed)

    // Prioritize horizontal movement
    if deltaMove.x == 0 {
        deltaMove.y = dm.GetAxisInt(globals.input, .Down, .Up, .JustPressed)
    }

    if deltaMove != {0, 0} {
        targetPos := player.position + deltaMove
        player.direction = HeadingFromDir(deltaMove)

        moved, movedTile := MoveEntityIfPossible(gameState.world, player, targetPos)
        if moved {
            targetEntity := dm.GetElement(gameState.entities, auto_cast movedTile.traversableEntity)
            if targetEntity != nil && (.Pickup in targetEntity.flags) {
                gameState.gold += targetEntity.goldValue
                DestroyEntity(targetEntity.handle)
            }
        }
    }

    if dm.GetKeyState(globals.input, .Space) == .JustPressed {
        DestroyWallAt(gameState.world,  player.position + Dir(player.direction))
    }
}

////////////////

CreateGoldPickup :: proc(world: World, position: dm.iv2, value: int) -> ^Entity {
    gold := CreateEntity()

    gold.position = position

    gold.sprite = dm.CreateSprite(gameState.atlas, {5 * 16, 0, 16, 16})
    gold.tint = GoldColor

    gold.goldValue = value

    gold.flags = { .Pickup, .Traversable }

    PutEntityInWorld(world, gold)

    return gold
}