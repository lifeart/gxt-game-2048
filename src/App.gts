import { Component, tracked, cellFor } from '@lifeart/gxt';

type Tile = {
  value: number;
  id: number;
  merged: boolean;
  className: string;
  previousPosition: { x: number; y: number } | null;
  x: number;
  y: number;
  isNew: boolean;
};

export default class Game2048 extends Component {
  @tracked tiles: Tile[] = [];

  @tracked score = 0;
  @tracked gameOver = false;
  @tracked maxScore = 0;

  gridSize = 4;
  tileId = 0;

  constructor() {
    // @ts-expect-error args
    super(...arguments);
    this.loadState();
    if (this.tiles.length === 0) {
      this.setupNewGame();
    }
    try {
      window.Telegram.WebApp.disableVerticalSwipes();
    } catch (e) {
      // EOL
    }
  }

  setupNewGame() {
    this.tiles = [];
    this.score = 0;
    this.gameOver = false;
    this.tileId = 0;
    this.addRandomTile();
    this.addRandomTile();
    this.prepareTiles();
    this.saveState();
  }

  addRandomTile() {
    const emptyCells = [];
    for (let x = 0; x < this.gridSize; x++) {
      for (let y = 0; y < this.gridSize; y++) {
        if (!this.getTileAt(x, y)) {
          emptyCells.push({ x, y });
        }
      }
    }
    if (emptyCells.length === 0) {
      return;
    }
    const randomCell =
      emptyCells[Math.floor(Math.random() * emptyCells.length)];
    const tile: Tile = {
      value: Math.random() < 0.9 ? 2 : 4,
      id: this.tileId++,
      merged: false,
      className: '',
      previousPosition: null,
      x: randomCell.x,
      y: randomCell.y,
      isNew: true,
    };
    cellFor(tile, 'value');
    cellFor(tile, 'merged');
    cellFor(tile, 'className');
    cellFor(tile, 'previousPosition');
    cellFor(tile, 'x');
    cellFor(tile, 'y');
    cellFor(tile, 'isNew');
    this.updateTileClass(tile);
    this.tiles.push(tile);
    this.tiles = [...this.tiles];
  }

  updateTileClass(tile: Tile) {
    const valueClassMap = {
      2: 'bg-yellow-100 text-yellow-900',
      4: 'bg-yellow-200 text-yellow-900',
      8: 'bg-yellow-300 text-yellow-900',
      16: 'bg-yellow-400 text-yellow-900',
      32: 'bg-orange-500 text-white',
      64: 'bg-orange-600 text-white',
      128: 'bg-orange-700 text-white',
      256: 'bg-red-500 text-white',
      512: 'bg-red-600 text-white',
      1024: 'bg-red-700 text-white',
      2048: 'bg-green-500 text-white',
      4096: 'bg-green-600 text-white',
      8192: 'bg-green-700 text-white',
    };
    const baseClass =
      'tile absolute flex items-center justify-center font-bold text-2xl';
    tile.className = `${baseClass} ${
      valueClassMap[tile.value] || 'bg-gray-500 text-white'
    }`;
  }

  handleKeyDown = (event: KeyboardEvent) => {
    if (this.gameOver) {
      return;
    }
    let moved = false;
    switch (event.key) {
      case 'ArrowUp':
        moved = this.move('up');
        break;
      case 'ArrowDown':
        moved = this.move('down');
        break;
      case 'ArrowLeft':
        moved = this.move('left');
        break;
      case 'ArrowRight':
        moved = this.move('right');
        break;
    }
    if (moved) {
      this.addRandomTile();
      if (!this.canMove()) {
        this.gameOver = true;
      }
    }
    this.saveState();
  };

  move(direction: 'up' | 'down' | 'left' | 'right'): boolean {
    let moved = false;
    const vectors = this.getVector(direction);
    const traversals = this.buildTraversals(vectors);

    this.prepareTiles();

    traversals.x.forEach((x) => {
      traversals.y.forEach((y) => {
        const tile = this.getTileAt(x, y);
        if (tile) {
          const positions = this.findFarthestPosition({ x, y }, vectors);
          const nextTile = this.getTileAt(positions.next.x, positions.next.y);

          if (nextTile && nextTile.value === tile.value && !nextTile.merged) {
            // Merge tiles
            this.mergeTiles(tile, nextTile);
            moved = true;
          } else {
            if (
              positions.farthest.x !== tile.x ||
              positions.farthest.y !== tile.y
            ) {
              this.moveTile(tile, positions.farthest);
              moved = true;
            }
          }
        }
      });
    });

    this.tiles = this.tiles.filter((tile) => tile.value !== 0);

    return moved;
  }

  prepareTiles() {
    this.tiles.forEach((tile) => {
      tile.merged = false;
      tile.previousPosition = { x: tile.x, y: tile.y };
      tile.isNew = false;
    });
  }

  mergeTiles(source: Tile, target: Tile) {
    target.value *= 2;
    target.merged = true;
    this.updateTileClass(target);
    this.score += target.value;
    if (this.score > this.maxScore) {
      this.maxScore = this.score;
    }

    try {
      window.Telegram.WebApp.HapticFeedback.impactOccurred('light');
    } catch (e) {
      // FINE
    }
    source.value = 0; // Mark source tile for removal
  }

  moveTile(tile: Tile, position: { x: number; y: number }) {
    tile.previousPosition = { x: tile.x, y: tile.y };
    tile.x = position.x;
    tile.y = position.y;
  }

  buildTraversals(vector: { x: number; y: number }) {
    const traversals = { x: [], y: [] };

    for (let pos = 0; pos < this.gridSize; pos++) {
      traversals.x.push(pos);
      traversals.y.push(pos);
    }

    if (vector.x === 1) {
      traversals.x = traversals.x.reverse();
    }
    if (vector.y === 1) {
      traversals.y = traversals.y.reverse();
    }

    return traversals;
  }

  findFarthestPosition(
    position: { x: number; y: number },
    vector: { x: number; y: number },
  ) {
    let previous;
    let next = position;

    do {
      previous = next;
      next = { x: previous.x + vector.x, y: previous.y + vector.y };
    } while (this.withinBounds(next) && !this.getTileAt(next.x, next.y));

    return {
      farthest: previous,
      next: next,
    };
  }

  getVector(direction: string) {
    const map = {
      up: { x: -1, y: 0 },
      down: { x: 1, y: 0 },
      left: { x: 0, y: -1 },
      right: { x: 0, y: 1 },
    };
    return map[direction];
  }

  withinBounds(position: { x: number; y: number }) {
    return (
      position.x >= 0 &&
      position.x < this.gridSize &&
      position.y >= 0 &&
      position.y < this.gridSize
    );
  }

  getTileAt(x: number, y: number) {
    return this.tiles.find(
      (tile) => tile.x === x && tile.y === y && tile.value !== 0,
    );
  }

  canMove() {
    for (let x = 0; x < this.gridSize; x++) {
      for (let y = 0; y < this.gridSize; y++) {
        const tile = this.getTileAt(x, y);
        if (!tile) {
          return true;
        }
        const directions = ['up', 'down', 'left', 'right'];
        for (let dir of directions) {
          const vector = this.getVector(dir);
          const nextPos = { x: x + vector.x, y: y + vector.y };
          if (this.withinBounds(nextPos)) {
            const nextTile = this.getTileAt(nextPos.x, nextPos.y);
            if (!nextTile || nextTile.value === tile.value) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  resetGame = () => {
    this.setupNewGame();
    try {
      window.Telegram.WebApp.HapticFeedback.notificationOccurred('success');
    } catch (e) {
      // FINE
    }
  };

  gridDisplaySize = Math.min(400, window.innerWidth);

  get tileSize() {
    return (this.gridDisplaySize / this.gridSize) * 0.8;
  }

  get gridWidth() {
    return `${this.gridDisplaySize}px`;
  }
  get gridHeigh() {
    return `${this.gridDisplaySize}px`;
  }
  get gridPlaceholder() {
    return new Array(this.gridSize).fill(null).map((_e, i) => {
      return {
        value: i,
      };
    });
  }

  get tileSizeInPX() {
    return `${this.tileSize}px`;
  }
  touchStartX = 0;
  touchStartY = 0;

  handleTouchStart = (event: TouchEvent) => {
    if (event.touches.length !== 1) {
      return;
    }
    this.touchStartX = event.touches[0].clientX;
    this.touchStartY = event.touches[0].clientY;
  };

  handleTouchEnd = (event: TouchEvent) => {
    if (this.gameOver) {
      return;
    }
    const dx = event.changedTouches[0].clientX - this.touchStartX;
    const dy = event.changedTouches[0].clientY - this.touchStartY;

    const absDx = Math.abs(dx);
    const absDy = Math.abs(dy);

    let moved = false;

    if (Math.max(absDx, absDy) > 10) {
      if (absDx > absDy) {
        // Horizontal swipe
        if (dx > 0) {
          moved = this.move('right');
        } else {
          moved = this.move('left');
        }
      } else {
        // Vertical swipe
        if (dy > 0) {
          moved = this.move('down');
        } else {
          moved = this.move('up');
        }
      }
    }

    if (moved) {
      this.addRandomTile();
      if (!this.canMove()) {
        this.gameOver = true;
        try {
          window.Telegram.WebApp.HapticFeedback.notificationOccurred('error');
        } catch (e) {
          // FINE
        }
      }
    }
    this.saveState();
  };

  stateToSave: null | {
    tiles: { value: number; x: number; y: number; id: number }[];
    score: number;
    maxScore: number;
    gameOver: boolean;
    tileId: number;
  } = null;

  saveState() {
    const gameState = {
      tiles: this.tiles.map((tile) => ({
        value: tile.value,
        x: tile.x,
        y: tile.y,
        id: tile.id,
      })),
      score: this.score,
      maxScore: this.maxScore,
      gameOver: this.gameOver,
      tileId: this.tileId,
    };
    this.stateToSave = gameState;
    this.hideMerged();
    clearTimeout(this.saveTimeout);
    this.saveTimeout = setTimeout(()=> this.lazySave(), 10000); // 10s per save
  }

  saveTimeout = -1;
  lazySave() {
    clearTimeout(this.saveTimeout);
    const gameState = this.stateToSave;
    localStorage.setItem('gameState', JSON.stringify(gameState));
    try {
      if (this.score === 0) {
        return;
      }
      window.Telegram.WebApp.CloudStorage.setItem(
        'game-2048-state',
        JSON.stringify(gameState),
      );
    } catch (e) {
      // FINE
    }
  }

  get showMaxScore() {
    return this.maxScore > this.score;
  }

  mergedTimeout: number | undefined = -1;
  hideMerged() {
    clearTimeout(this.mergedTimeout);
    this.mergedTimeout = setTimeout(() => {
      requestAnimationFrame(() => {
        this.tiles.forEach((t) => (t.merged = false));
      });
    }, 200);
  }

  applyState(gameState) {
    this.tiles = gameState.tiles.map((tileData) => {
      const tile: Tile = {
        value: tileData.value,
        id: tileData.id,
        merged: false,
        className: '',
        previousPosition: null,
        x: tileData.x,
        y: tileData.y,
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
    });
    this.score = gameState.score;
    this.maxScore = gameState.maxScore || gameState.score;
    this.gameOver = gameState.gameOver;
    this.tileId = gameState.tileId;
  }
  loadState() {
    const savedState = localStorage.getItem('gameState');
    if (savedState) {
      try {
        const gameState = JSON.parse(savedState);
        this.applyState(gameState);
      } catch (e) {
        this.setupNewGame();
      }
    }

    try {
      window.Telegram.WebApp.CloudStorage.getItem(
        'game-2048-state',
        (err, raw) => {
          if (!err) {
            const value = JSON.parse(raw);
            this.applyState(value);
          }
        },
      );
    } catch (e) {
      // FINE
    }
  }

  focus = (e: HTMLDivElement) => {
    requestAnimationFrame(() => {
      e.focus();
    });
    const focusTrap = () => {
      e.focus();
    };
    document.body.addEventListener('click', focusTrap);
    return () => {
      document.body.removeEventListener('click', focusTrap);
    };
  };

  <template>
    <div class='flex flex-col items-center justify-start min-h-screen'>
      <h1 class='text-4xl font-bold mb-4 mt-4'>2048 Game</h1>
      <div class='text-2xl mb-4'>Score:
        {{this.score}}{{#if this.showMaxScore}}, Max:
          {{this.maxScore}}{{/if}}</div>
      <div
        class='game-container relative'
        style.width={{this.gridWidth}}
        style.height={{this.gridHeigh}}
        {{on 'keydown' this.handleKeyDown}}
        {{on 'touchstart' this.handleTouchStart}}
        {{on 'touchend' this.handleTouchEnd}}
        {{this.focus}}
        tabindex='0'
      >
        <!-- Grid Background -->
        {{#each this.gridPlaceholder as |row|}}
          {{#each this.gridPlaceholder as |col|}}
            <div
              class='tile-empty'
              style.width={{this.tileSizeInPX}}
              style.height={{this.tileSizeInPX}}
              style.top={{this.position row.value}}
              style.left={{this.position col.value}}
            ></div>
          {{/each}}
        {{/each}}

        <!-- Tiles -->
        {{#each this.tiles as |tile|}}
          <div
            class={{tile.className}}
            style.width={{this.tileSizeInPX}}
            style.height={{this.tileSizeInPX}}
            style.top={{this.position tile.x}}
            style.left={{this.position tile.y}}
            style.transform={{this.tileTransform tile}}
          >
            {{tile.value}}
          </div>
        {{/each}}
      </div>
      {{#if this.gameOver}}
        <div class='mt-4 text-red-600 text-xl font-bold'>Game Over!</div>
      {{/if}}
      <button
        type='button'
        class='mt-4 px-4 py-2 bg-blue-500 text-white rounded'
        {{on 'click' this.resetGame}}
      >New Game</button>
    </div>
  </template>

  position(index: number) {
    let offset =
      (this.gridDisplaySize - this.gridSize * this.tileSize) /
      (this.gridSize - 1);
    return `${index * this.tileSize + (offset / 2) * (index + 1.5)}px`;
  }

  tileTransform(tile: Tile) {
    let transform = '';
    if (tile.isNew) {
      transform = 'scale(0)';
    } else if (tile.merged) {
      transform = 'scale(1.2)';
    } else {
      transform = 'scale(1)';
    }
    return transform;
  }
}
