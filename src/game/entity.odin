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
    Enemy,
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
    detectionRadius: int,

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

DamageEntity :: proc(entity: ^Entity, damage: int) {
    entity.HP -= damage

    if entity.HP <= 0 {
        DestroyEntity(entity.handle)
    }
}

////////////

ControlEntity :: proc(entity: ^Entity) {
    switch(entity.controler) {
        case .Player: ControlPlayer(entity)
        case .Enemy:  ControlEnemy(entity)
        case .None: // ignore
    }
}

GetFacingEntity :: proc(self: ^Entity) -> ^Entity {
    pos := self.position + Dir(self.direction)
    tile := GetWorldTile(gameState.world, pos)

    return dm.GetElement(gameState.entities, auto_cast tile.holdedEntity)
}

GetFacingEntityHandle :: proc(self: ^Entity) -> EntityHandle {
    pos := self.position + Dir(self.direction)
    tile := GetWorldTile(gameState.world, pos)

    return tile.holdedEntity
}

////////////

CreatePlayerEntity :: proc() -> ^Entity {
    player := CreateEntity()

    player.controler = .Player
    player.sprite = dm.CreateSprite(gameState.atlas, {0, 0, 16, 16})
    player.tint = PlayerColor

    player.flags = {.HP, .CanAttack, }

    player.HP = 100

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

        gameState.playerMovedThisFrame = true
    }

    if dm.GetKeyState(globals.input, .Space) == .JustPressed {
        tile := GetWorldTile(gameState.world, player.position + Dir(player.direction))

        if tile.isWall {
            DestroyWallAt(gameState.world,  player.position + Dir(player.direction))
        }

        entity := dm.GetElement(gameState.entities, auto_cast tile.holdedEntity)
        if entity != nil && .HP in entity.flags {
            DamageEntity(entity, 10)
        }

        gameState.playerMovedThisFrame = true
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

/////////////////

CreateEnemy :: proc(world: World, position: dm.iv2) -> ^Entity {
    enemy := CreateEntity()

    enemy.position = position

    enemy.sprite = dm.CreateSprite(gameState.atlas, {0, 16, 16, 16})
    enemy.tint = EnemyColor

    enemy.controler = .Enemy

    enemy.detectionRadius = 5
    enemy.HP = 10
    // enemy.goldValue = 0


    enemy.flags = { .HP, .CanAttack }

    PutEntityInWorld(world, enemy)

    return enemy
}

ControlEnemy :: proc(enemy: ^Entity) {
    if gameState.playerMovedLastFrame == false {
        return
    }

    player := GetPlayer() 
    if player == nil {
        return
    }

    playerDir := player.position - enemy.position
    dist := playerDir.x * playerDir.x + playerDir.y * playerDir.y

    if dist != 1 && int(dist) < enemy.detectionRadius * enemy.detectionRadius {
        dir: dm.iv2
        if abs(playerDir.x) > abs(playerDir.y) {
            dir.x = glsl.sign(playerDir.x)
        }
        else {
            dir.y = glsl.sign(playerDir.y)
        }

        MoveEntityIfPossible(gameState.world, enemy, enemy.position + dir)
        enemy.direction = HeadingFromDir(dir)
    }

    if dist == 1 {
        otherHandle := GetFacingEntityHandle(enemy)
        if otherHandle == player.handle {
            DamageEntity(player, 10)            
        }
    }
}