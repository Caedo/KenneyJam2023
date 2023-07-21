package game

import dm "../dmcore"

import "core:math/rand"

WorldSize :: dm.iv2{5,  5}
ChunkSize :: dm.iv2{32, 32}

World :: struct {
    chunks: []Chunk,
}

Chunk :: struct {
    offset: dm.iv2,
    tiles: []Tile,
}

Tile :: struct {
    genHelper: u32, // 0 if empty, 1 if occupied

    position: dm.iv2,
    sprite: dm.Sprite,

    holdedEntity: EntityHandle,
}

InitChunk :: proc(chunk: ^Chunk) {
    chunk.tiles = make([]Tile, ChunkSize.x * ChunkSize.y)

    for y in 0..<ChunkSize.y {
        for x in 0..<ChunkSize.x {
            idx := y * ChunkSize.x + x

            chunk.tiles[idx].genHelper = rand.uint32() % 2
            chunk.tiles[idx].sprite    = dm.CreateSprite(gameState.atlas, {0, 32, 16, 16})
            chunk.tiles[idx].position  = {x, y}
        }
    }
}

CreateWorld :: proc() -> (world: World) {
    world.chunks = make([]Chunk, WorldSize.x * WorldSize.y)

    for &chunk, i in world.chunks {
        chunk.offset = {
            i32(i) % WorldSize.x,
            i32(i) / WorldSize.x
        }

        InitChunk(&chunk)
    }

    return
}

IsInsideChunk :: proc(pos: dm.iv2) -> bool {
    return pos.x >= 0 && pos.x < ChunkSize.x &&
           pos.y >= 0 && pos.y < ChunkSize.y
}

GetTile :: proc(chunk: Chunk, x, y: i32) -> ^Tile {
    idx := y * ChunkSize.x + x
    return &chunk.tiles[idx]
} 

GetNeighboursCount :: proc(pos: dm.iv2, chunk: Chunk) -> (count: u32) {
    for y in pos.y - 1 ..= pos.y + 1 {
        for x in pos.x - 1 ..= pos.x + 1 {
            neighbour := dm.iv2{x, y}

            if neighbour == pos {
                continue
            }

            if IsInsideChunk(neighbour) {
                count += GetTile(chunk, neighbour.x, neighbour.y).genHelper
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

                tile := GetTile(chunk, x, y)
                count := GetNeighboursCount({x, y}, chunk)

                if count < 4 {
                    tile.genHelper = 0
                }
                else if count > 4 {
                    tile.genHelper = 1
                }
            }
        }
    }
}