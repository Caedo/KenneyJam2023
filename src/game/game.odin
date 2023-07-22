package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"


ColorGround : dm.color : { 71./255., 45./255., 60./255., 1 }
PlayerColor : dm.color : dm.WHITE
EnemyColor  : dm.color : dm.RED
WallColor   : dm.color : { 207./255., 198./255., 184./255., 1 }


gameState: ^GameState

GameState :: struct {
    world: World,
    entities: dm.ResourcePool(Entity),

    atlas: dm.TexHandle,
    targetSprite: dm.Sprite,

    playerHandle: EntityHandle,

    camera: dm.Camera,

    topWallSprite: dm.Sprite,
    botWallSprite: dm.Sprite,
    leftWallSprite: dm.Sprite,
    rightWallSprite: dm.Sprite,
    topLeftWallSprite: dm.Sprite,
    topRightWallSprite: dm.Sprite,
    botLeftWallSprite: dm.Sprite,
    botRightWallSprite: dm.Sprite,
    filledWallSprite: dm.Sprite,
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)
    dm.InitResourcePool(&gameState.entities, 1024)

    gameState.camera = dm.CreateCamera(7, 4./3., 0.0001, 1000)
    gameState.camera.position.z = 1

    gameState.atlas = dm.LoadTextureFromFile("assets/atlas.png", globals.renderCtx)
    gameState.targetSprite = dm.CreateSprite(gameState.atlas, {16, 0, 16, 16})

    wallSprite := dm.CreateSprite(gameState.atlas, {16 * 3, 16, 16, 16})
    wallSprite.tint = WallColor

    gameState.filledWallSprite = wallSprite

    wallSprite.atlasPos.y -= 16
    gameState.topWallSprite = wallSprite

    wallSprite.atlasPos.x -= 16
    gameState.topLeftWallSprite = wallSprite

    wallSprite.atlasPos.y += 16
    gameState.leftWallSprite = wallSprite

    wallSprite.atlasPos.y += 16
    gameState.botLeftWallSprite = wallSprite

    wallSprite.atlasPos.x += 16
    gameState.botWallSprite = wallSprite

    wallSprite.atlasPos.x += 16
    gameState.botRightWallSprite = wallSprite

    wallSprite.atlasPos.y -= 16
    gameState.rightWallSprite = wallSprite

    wallSprite.atlasPos.y -= 16
    gameState.topRightWallSprite = wallSprite

    // gameState.camera.orthoSize = f32(ChunkSize.x * WorldSize.x) / 2
    // gameState.camera.position = {
    //     -f32(WorldSize.x * ChunkSize.x) / 2,
    //     -f32(WorldSize.y * ChunkSize.y) / 2,
    //     -1
    // }


    ////////////////////////////

    gameState.playerHandle = CreatePlayerEntity()

    gameState.world = CreateWorld()

    for chunk in gameState.world.chunks {
        UpdateChunk(gameState.world, chunk)
    }

}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, auto_cast e.handle) == false {
            continue
        }


        ControlEntity(&e)
    }


    player := dm.GetElement(gameState.entities, auto_cast gameState.playerHandle)
    assert(dm.IsHandleValid(gameState.entities, auto_cast gameState.playerHandle))

    gameState.camera.position.x = cast(f32) player.position.x
    gameState.camera.position.y = cast(f32) player.position.y
    // gameState.camera.position.x += dm.GetAxis(globals.input, .A, .D) * globals.time.deltaTime
    // gameState.camera.position.y += dm.GetAxis(globals.input, .S, .W) * globals.time.deltaTime


    ///////////////////
    @static selectedTile: ^Tile
    if dm.GetMouseButton(globals.input, .Left) == .JustPressed {
        mousePos := globals.input.mousePos
        normPos := dm.v2{f32(mousePos.x) / f32(globals.renderCtx.frameSize.x), 
                         f32(mousePos.y) / f32(globals.renderCtx.frameSize.y)} * 2 - 1

        camPos := gameState.camera.position
        camHeight := gameState.camera.orthoSize
        camWidth  := gameState.camera.aspect * camHeight

        worldPos := dm.v2{camPos.x, camPos.y} + normPos * {camWidth, -camHeight}
        worldPos = math.round(worldPos)
        fmt.println(worldPos)

    
        selectedTile = GetWorldTile(gameState.world, {i32(worldPos.x), i32(worldPos.y)})
    }

    

    if dm.muiBeginWindow(globals.mui, "Debug", {0, 0, 150, 120}, nil) {
        if dm.muiButton(globals.mui, "Refresh") {
            for chunk in gameState.world.chunks {
                UpdateChunk(gameState.world, chunk)
            }
        }

        if selectedTile != nil {
            dm.muiLabel(globals.mui, selectedTile)
        }

        dm.muiEndWindow(globals.mui)
    }

}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    dm.SetCamera(globals.renderCtx, gameState.camera)
    dm.ClearColor(globals.renderCtx, ColorGround)

    ctx := globals.renderCtx
    
    for chunk in gameState.world.chunks {
        for tile in chunk.tiles {
            if tile.isWall {
                assert(tile.sprite.texture.index != 0)
                dm.DrawSprite(ctx, tile.sprite, dm.v2Conv(tile.position))
            }
        }
    }

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, auto_cast e.handle) == false {
            continue
        }

        dm.DrawSprite(ctx, e.sprite, dm.v2Conv(e.position))
        dm.DrawSprite(ctx, gameState.targetSprite, dm.v2Conv(e.position + Dir(e.direction)))
    }
}