package game

import dm "../dmcore"

import "core:math/rand"
import "core:fmt"

WorldSize :: dm.iv2{5,  5}
ChunkSize :: dm.iv2{32, 32}

GenSteps :: 4

World :: struct {
    chunks: []Chunk,
}

Chunk :: struct {
    offset: dm.iv2,
    tiles: []Tile,
}

Tile :: struct {
    chunk: ^Chunk,

    position: dm.iv2,
    localPos: dm.iv2,

    neighbours: HeadingsSet,
    isWall: bool,
    indestructible: bool,
    sprite: dm.Sprite,

    traversableEntity: EntityHandle,
    holdedEntity: EntityHandle,
}

HeadingsSet :: bit_set[Heading]
Top      :: HeadingsSet{ .South, .West, .East }
Bot      :: HeadingsSet{ .North, .West, .East }
Left     :: HeadingsSet{ .South, .North, .East }
Right    :: HeadingsSet{ .South, .North, .West }
BotRight :: HeadingsSet{ .North, .West }
BotLeft  :: HeadingsSet{ .North, .East }
TopRight :: HeadingsSet{ .South, .West }
TopLeft  :: HeadingsSet{ .South, .East }

InitChunk :: proc(chunk: ^Chunk) {
    chunk.tiles = make([]Tile, ChunkSize.x * ChunkSize.y)

    for y in 0..<ChunkSize.y {
        for x in 0..<ChunkSize.x {
            idx := y * ChunkSize.x + x

            chunk.tiles[idx].isWall = (rand.uint32() % 2) == 1

            chunk.tiles[idx].sprite    = dm.CreateSprite(gameState.atlas, {0, 32, 16, 16})
            chunk.tiles[idx].localPos  = {x, y}
            chunk.tiles[idx].position  = chunk.offset * ChunkSize + {x, y}

            chunk.tiles[idx].chunk = chunk
        }
    }
}

CreateWorld :: proc() -> (world: World) {
    world.chunks = make([]Chunk, WorldSize.x * WorldSize.y)

    rand.set_global_seed(0)

    for &chunk, i in world.chunks {
        chunk.offset = {
            i32(i) % WorldSize.x,
            i32(i) / WorldSize.x
        }

        InitChunk(&chunk)
    }

    for step in 0..<GenSteps {
        GenStep(&world)
    }

    worldSize := WorldSize * ChunkSize

    for x in 0..<worldSize.x {
        tileA := GetWorldTile(world, {x, 0})
        tileB := GetWorldTile(world, {x, worldSize.y - 1})

        tileA.isWall = true
        tileB.isWall = true

        tileA.indestructible = true
        tileB.indestructible = true
    }

    for y in 0..<worldSize.y {
        tileA := GetWorldTile(world, {0, y})
        tileB := GetWorldTile(world, {worldSize.x - 1, y})

        tileA.isWall = true
        tileB.isWall = true

        tileA.indestructible = true
        tileB.indestructible = true
    }

    return
}

IsInsideChunk :: proc(pos: dm.iv2) -> bool {
    return pos.x >= 0 && pos.x < ChunkSize.x &&
           pos.y >= 0 && pos.y < ChunkSize.y
}

IsInsideWorld :: proc(pos: dm.iv2) -> bool {
    return pos.x >= 0 && pos.x < ChunkSize.x * WorldSize.x &&
           pos.y >= 0 && pos.y < ChunkSize.y * WorldSize.y
}

GetWorldTile :: proc(world: World, pos: dm.iv2) -> ^Tile {
    chunkPos := pos / ChunkSize
    idx := chunkPos.y * WorldSize.x + chunkPos.x

    localPos := pos - chunkPos * ChunkSize

    return GetTile(world.chunks[idx], localPos)
}

GetTile :: proc(chunk: Chunk, pos: dm.iv2) -> ^Tile {
    idx := pos.y * ChunkSize.x + pos.x
    return &chunk.tiles[idx]
}

IsTileOccupied :: proc(world: World, worldPos: dm.iv2) -> bool {
    tile := GetWorldTile(world, worldPos)
    validHandle := dm.IsHandleValid(gameState.entities, auto_cast tile.holdedEntity)

    return tile.isWall || validHandle
}

DestroyWallAt :: proc(world: World, worldPos: dm.iv2) -> bool {
    tile := GetWorldTile(world, worldPos)
    assert(tile != nil)

    if tile.indestructible == false {
        tile.isWall = false
        UpdateChunk(world, tile.chunk^)
        
        return true
    }
    else {
        return false
    }
}

GetNeighboursCount :: proc(pos: dm.iv2, chunk: Chunk) -> (count: u32) {
    for y in pos.y - 1 ..= pos.y + 1 {
        for x in pos.x - 1 ..= pos.x + 1 {
            neighbour := dm.iv2{x, y}

            if neighbour == pos {
                continue
            }

            if IsInsideChunk(neighbour) {
                count += GetTile(chunk, neighbour).isWall ? 1 : 0
            }
            else {
                count += 1
            }
        }
    }

    return
}

GenStep :: proc(world: ^World) {
    for chunk in world.chunks {

        for y in 0..<ChunkSize.y {
            for x in 0..<ChunkSize.x {
                idx := y * ChunkSize.x + x

                tile := GetTile(chunk, {x, y})
                count := GetNeighboursCount({x, y}, chunk)

                if count < 4 {
                    tile.isWall = false
                }
                else if count > 4 {
                    tile.isWall = true
                }
            }
        }
    }
}

UpdateChunk :: proc(world: World, chunk: Chunk) {
    for &t in chunk.tiles {
        @static checkedDirections:= [?]dm.iv2{
            {1, 0},
            {-1, 0},
            {0, 1},
            {0, -1},
        }

        t.neighbours = nil
        for dir in checkedDirections {
            pos :=  t.position + dir
            // @TODO: probably wont to treat world edge as a wall
            if IsInsideWorld(pos) == false {
                continue
            }

            tile := GetWorldTile(world, pos)

            if tile.isWall {
                t.neighbours += { HeadingFromDir(dir) }
            }
        }

        // fmt.println(t.neighbours)
        switch t.neighbours {
            case Top:      t.sprite = gameState.topWallSprite
            case Bot:      t.sprite = gameState.botWallSprite
            case Left:     t.sprite = gameState.leftWallSprite
            case Right:    t.sprite = gameState.rightWallSprite
            case BotRight: t.sprite = gameState.botRightWallSprite
            case BotLeft:  t.sprite = gameState.botLeftWallSprite
            case TopRight: t.sprite = gameState.topRightWallSprite
            case TopLeft:  t.sprite = gameState.topLeftWallSprite
            case:          t.sprite = gameState.filledWallSprite
        }
    }
}

//////////////

PutEntityInWorld :: proc(world: World, entity: ^Entity) {
    tile := GetWorldTile(world, entity.position)

    if .Traversable in entity.flags {
        tile.traversableEntity = entity.handle
    }
    else {
        tile.holdedEntity = entity.handle
    }

}

MoveEntityIfPossible :: proc(world: World, entity: ^Entity, targetPos: dm.iv2) {
    if IsTileOccupied(world, targetPos) == false {
        currentTile := GetWorldTile(world, entity.position)
        targetTile := GetWorldTile(world, targetPos)

        currentTile.holdedEntity = {0, 0}
        targetTile.holdedEntity = entity.handle

        entity.position = targetPos
    }
}