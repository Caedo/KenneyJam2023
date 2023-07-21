package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"

gameState: ^GameState


GameState :: struct {
    world: World,
    entities: dm.ResourcePool(Entity),
    
    atlas: dm.TexHandle,

    playerHandle: EntityHandle,

    camera: dm.Camera
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)
    dm.InitResourcePool(&gameState.entities, 1024)

    gameState.camera = dm.CreateCamera(2, 4./3., 0.0001, 1000)
    gameState.camera.position.z = -1

    gameState.atlas = dm.LoadTextureFromFile("assets/atlas.png", globals.renderCtx)

    gameState.playerHandle = CreatePlayerEntity()

    gameState.world = CreateWorld()

    gameState.camera.orthoSize = f32(ChunkSize.x * WorldSize.x) / 2
    gameState.camera.position = {
        -f32(WorldSize.x * ChunkSize.x) / 2,
        -f32(WorldSize.y * ChunkSize.y) / 2,
        -1
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

    // camera.position.x += dm.GetAxis(globals.input, .A, .D) * globals.time.deltaTime
    // camera.position.y += dm.GetAxis(globals.input, .S, .W) * globals.time.deltaTime

    if dm.muiBeginWindow(globals.mui, "Gen Text", {0, 0, 100, 70}, nil) {
        if dm.muiButton(globals.mui, "Step") {
            GenStep(&gameState.world)
        }

        dm.muiEndWindow(globals.mui)
    }
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    dm.SetCamera(globals.renderCtx, gameState.camera)
    dm.ClearColor(globals.renderCtx, {0.1, 0.3, 1, 1})

    ctx := globals.renderCtx
    
    for chunk in gameState.world.chunks {
        for tile in chunk.tiles {
            pos := chunk.offset * ChunkSize + tile.position
            if tile.genHelper == 1 {
                dm.DrawSprite(ctx, tile.sprite, dm.v2Conv(pos))
            }
        }
    }

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, auto_cast e.handle) == false {
            continue
        }

        dm.DrawSprite(ctx, e.sprite, dm.v2Conv(e.position))
    }
}