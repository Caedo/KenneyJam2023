package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"

gameState: ^GameState


GameState :: struct {
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

}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    dm.SetCamera(globals.renderCtx, gameState.camera)
    dm.ClearColor(globals.renderCtx, {0.1, 0.3, 1, 1})

    ctx := globals.renderCtx

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, auto_cast e.handle) == false {
            continue
        }

        dm.DrawSprite(ctx, e.sprite, dm.v2Conv(e.position))
    }
}