import "decorator-transforms/globals";
import { module, test } from 'qunit';
import { render, rerender, click } from '@lifeart/gxt/test-utils';
import Game2048 from './../../App.gts';
import { cellFor } from '@lifeart/gxt';

async function triggerKeyEvent(
  element: HTMLElement,
  eventType: string,
  key: string
) {
  const event = new KeyboardEvent(eventType, {
    key,
    bubbles: true,
    cancelable: true,
  });
  element.dispatchEvent(event);
  await rerender();
}

module('Integration | Component | Game2048', function (hooks) {
  hooks.beforeEach(function () {
    localStorage.clear();
  });

  test('it renders the initial game state correctly', async function (assert) {
    await render(<template><Game2048 /></template>);

    // Check initial score
    assert.dom('.text-2xl').hasText('Score: 0', 'Initial score is displayed correctly');

    // Check that two tiles are present
    assert.dom('.tile').exists({ count: 2 }, 'There are two tiles on the board');

    // Ensure tiles have value 2 or 4
    this.element.querySelectorAll('.tile').forEach((tile) => {
      const value = parseInt(tile.textContent.trim());
      assert.ok(value === 2 || value === 4, 'Tile has value 2 or 4');
    });
  });

  test('moving tiles to the left adds a new tile', async function (assert) {
    await render(<template><Game2048 /></template>);

    const initialTileCount = this.element.querySelectorAll('.tile').length;

    // Simulate left arrow key press
    await triggerKeyEvent(this.element, 'keydown', 'ArrowLeft');
    await rerender();

    const newTileCount = this.element.querySelectorAll('.tile').length;
    assert.ok(newTileCount > initialTileCount, 'A new tile is added after moving left');
  });

  test('tiles merge correctly when moved', async function (assert) {
    class TestGame2048 extends Game2048 {
      setupNewGame() {
        this.tiles = [];
        this.score = 0;
        this.gameOver = false;
        this.tileId = 0;

        const tile1 = this.createTile(2, 0, 0);
        const tile2 = this.createTile(2, 0, 1);
        this.tiles.push(tile1, tile2);
      }

      createTile(value: number, x: number, y: number) {
        const tile: Tile = {
          value,
          id: this.tileId++,
          merged: false,
          className: '',
          previousPosition: null,
          x,
          y,
          isNew: false,
        };
        cellFor(tile, 'value');
        cellFor(tile, 'merged');
        cellFor(tile, 'className');
        cellFor(tile, 'previousPosition');
        cellFor(tile, 'x');
        cellFor(tile, 'y');
        cellFor(tile, 'isNew');
        this.updateTileClass(tile);
        return tile;
      }
    }

    await render(<template><TestGame2048 /></template>);

    // Verify initial state
    assert.dom('.tile').exists({ count: 2 }, 'Two tiles are on the board initially');

    // Simulate left arrow key press to merge tiles
    await triggerKeyEvent(this.element, 'keydown', 'ArrowLeft');
    await rerender();

    // Check that tiles have merged
    assert.dom('.tile').exists({ count: 2 }, 'Tiles merged into one, and a new tile is added');

    // Check for a tile with value 4
    const tileValues = Array.from(this.element.querySelectorAll('.tile')).map((tile) =>
      parseInt(tile.textContent.trim())
    );
    assert.ok(tileValues.includes(4), 'A tile with value 4 is present after merging');

    // Check that the score has updated
    assert.dom('.text-2xl').hasText('Score: 4', 'Score updated to 4 after merging tiles');
  });

  test('game over condition is detected', async function (assert) {
    class FullBoardGame2048 extends Game2048 {
      setupNewGame() {
        this.tiles = [];
        this.score = 0;
        this.gameOver = false;
        this.tileId = 0;

        // Fill the board with alternating 2s and 4s to prevent merging
        for (let x = 0; x < this.gridSize; x++) {
          for (let y = 0; y < this.gridSize; y++) {
            const value = (x + y) % 2 === 0 ? 2 : 4;
            const tile = this.createTile(value, x, y);
            this.tiles.push(tile);
          }
        }
      }

      createTile(value: number, x: number, y: number) {
        const tile: Tile = {
          value,
          id: this.tileId++,
          merged: false,
          className: '',
          previousPosition: null,
          x,
          y,
          isNew: false,
        };
        cellFor(tile, 'value');
        cellFor(tile, 'merged');
        cellFor(tile, 'className');
        cellFor(tile, 'previousPosition');
        cellFor(tile, 'x');
        cellFor(tile, 'y');
        cellFor(tile, 'isNew');
        this.updateTileClass(tile);
        return tile;
      }
    }

    await render(<template><FullBoardGame2048 /></template>);

    // Simulate moves in all directions
    await triggerKeyEvent(this.element, 'keydown', 'ArrowLeft');
    await triggerKeyEvent(this.element, 'keydown', 'ArrowRight');
    await triggerKeyEvent(this.element, 'keydown', 'ArrowUp');
    await triggerKeyEvent(this.element, 'keydown', 'ArrowDown');
    await rerender();

    // Check for game over message
    assert.dom('.mt-4').hasText('Game Over!', 'Game over message is displayed');
  });

  test('touch swipe moves tiles', async function (assert) {
    await render(<template><Game2048 /></template>);

    const initialTileCount = this.element.querySelectorAll('.tile').length;

    // Simulate touch events for swipe left
    const touchStartEvent = new TouchEvent('touchstart', {
      touches: [new Touch({ identifier: 0, target: this.element, clientX: 200, clientY: 200 })],
    });
    const touchEndEvent = new TouchEvent('touchend', {
      changedTouches: [new Touch({ identifier: 0, target: this.element, clientX: 100, clientY: 200 })],
    });

    this.element.dispatchEvent(touchStartEvent);
    this.element.dispatchEvent(touchEndEvent);
    await rerender();

    const newTileCount = this.element.querySelectorAll('.tile').length;
    assert.ok(newTileCount > initialTileCount, 'A new tile is added after swiping left');
  });

  test('game state is saved and loaded from local storage', async function (assert) {
    // Start a new game and make a move
    await render(<template><Game2048 /></template>);

    await triggerKeyEvent(this.element, 'keydown', 'ArrowLeft');
    await rerender();

    const tileValuesBeforeReload = Array.from(this.element.querySelectorAll('.tile')).map((tile) =>
      parseInt(tile.textContent.trim())
    );
    const scoreBeforeReload = parseInt(this.element.querySelector('.text-2xl').textContent.replace('Score: ', ''));

    // Reload the component to simulate page reload
    await render(<template><Game2048 /></template>);
    await rerender();

    const tileValuesAfterReload = Array.from(this.element.querySelectorAll('.tile')).map((tile) =>
      parseInt(tile.textContent.trim())
    );
    const scoreAfterReload = parseInt(this.element.querySelector('.text-2xl').textContent.replace('Score: ', ''));

    // Check that the tile values and score are the same
    assert.deepEqual(tileValuesAfterReload.sort(), tileValuesBeforeReload.sort(), 'Tile values are preserved after reload');
    assert.equal(scoreAfterReload, scoreBeforeReload, 'Score is preserved after reload');
  });

  test('new game button resets the game', async function (assert) {
    await render(<template><Game2048 /></template>);

    // Make some moves
    await triggerKeyEvent(this.element, 'keydown', 'ArrowLeft');
    await rerender();

    const scoreBeforeReset = parseInt(this.element.querySelector('.text-2xl').textContent.replace('Score: ', ''));

    // Click the New Game button
    await click('button');

    // Check that the score has been reset
    assert.dom('.text-2xl').hasText('Score: 0', 'Score is reset after starting a new game');

    // Check that there are two tiles on the board
    assert.dom('.tile').exists({ count: 2 }, 'Two tiles are on the board after starting a new game');

    // Check that the tiles are different from before
    const tileValuesAfterReset = Array.from(this.element.querySelectorAll('.tile')).map((tile) =>
      parseInt(tile.textContent.trim())
    );
    assert.notEqual(tileValuesAfterReset.reduce((a, b) => a + b, 0), scoreBeforeReset, 'Board is reset with new tiles');
  });
});
