package main

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"

ScreenWidth : i32 : 800 
ScreenHeight : i32 : 600

NUM_GENERATIONS :: 100
POPULATION_SIZE :: 20
MUTATION_RATE :: 0.6
TIME_STEPS :: 200
TARGET : rl.Rectangle : {f32(ScreenWidth-50), f32(ScreenHeight-50), 20, 20}

w1 : f32 : 1.5 // distance to target
w2 : f32 : 2.1 // collisions
w3 : f32 : 1.0 // how fast target reached

// START : rl.Vector2 : { f32(ScreenWidth/2), f32(ScreenHeight/2)}
START : rl.Vector2 : { 50, 50 }
SPEED :: 5

Individual :: struct {
	genes: [TIME_STEPS]byte,
	fitness: f32,
	rec: rl.Rectangle,
	collisions: int,
	targetReached: int,
}

Obstacle :: struct {
	rec: rl.Rectangle,
	color: rl.Color,
}

Moves := map[byte]rl.Vector2 {
	'0' = {5, 0},
	'1' = {0, 5},
	'2' = {-5, 0},
	'3' = {0, -5},
}

// GENETIC ALGORITHM

createInitialPopulation :: proc() -> []Individual {
	population := make([]Individual, POPULATION_SIZE)
	rng := rand.create(6084)
	
	for i := 0; i < POPULATION_SIZE; i+=1 {
		population[i] = createIndividual()
		for j := 0; j < TIME_STEPS; j+=1 {
			population[i].genes[j] = byte(rand.uint32(&rng) % 4)
		}
	}
	
	return population
}

createIndividual :: proc() -> Individual {
	individual: Individual
	
	individual.rec = rl.Rectangle{ START.x, START.y, 20, 20}

	return individual
}

evaluateFitness :: proc(individual: Individual) -> f32 {
	fitness: f32
	fitness -= w2 * f32(individual.collisions)
	// calculate distance from target
	distanceToTarget := rl.Vector2Distance({TARGET.x, TARGET.y}, {individual.rec.x, individual.rec.y})
	// math.sqrt_f32(math.pow2_f32(TARGET.x - individual.rec.x) + math.pow2_f32(TARGET.y - individual.rec.y))
	fitness += w1 * 1/distanceToTarget
	if individual.targetReached > 0 do fitness += w3 * f32(1/individual.targetReached)

	return fitness
}

selection :: proc(population: []Individual) -> []Individual {
	newPopulation := make([]Individual, POPULATION_SIZE)
	// for i in 0..<POPULATION_SIZE {
	// 	newPopulation[i] = createIndividual()
	// }
	
	rng := rand.create(u64(time.now()._nsec))
	
	// ROULETTE WHEEL
	// calculate total fitness
	totalFitness: f32
	for individual in population {
		totalFitness += individual.fitness
	}
	
	// calculate probabilities
	
	probabilities := make([]f32, POPULATION_SIZE)
	for individual, i in population {
		probabilities[i] = individual.fitness / totalFitness
	}
	
	// selection
	for i in 0..<POPULATION_SIZE {
		r := rand.float32(&rng)
		accumulatedProbability: f32 = 0
		for prob, j in probabilities {
			accumulatedProbability += prob
			if r < accumulatedProbability {
				newPopulation[i].genes = population[j].genes
				break
			}
		}
	}


	return newPopulation
}

breedNewPopulation :: proc(population: []Individual) -> []Individual {
	newPopulation := make([]Individual, POPULATION_SIZE)
	
	for i := 0; i<POPULATION_SIZE; i += 2 {
		offspring1, offspring2 := crossover(population[i], population[i+1])
		newPopulation[i] = offspring1
		newPopulation[i+1] = offspring2
	}

	return newPopulation
}

crossover :: proc(parent1: Individual, parent2: Individual) -> (Individual, Individual) {
	offspring1 := createIndividual()
	offspring2 := createIndividual()
	
	// one point crossover
	crossoverPoint := rl.GetRandomValue(0, TIME_STEPS)
	p1Genes := parent1.genes
	p2Genes := parent2.genes
	
	// offspring 1
	copy_slice(offspring1.genes[0:crossoverPoint], p1Genes[0:crossoverPoint])
	copy_slice(offspring1.genes[crossoverPoint:TIME_STEPS], p2Genes[crossoverPoint:TIME_STEPS])

	// offspring 2
	copy_slice(offspring2.genes[0:crossoverPoint], p2Genes[0:crossoverPoint])
	copy_slice(offspring2.genes[crossoverPoint:TIME_STEPS], p1Genes[crossoverPoint:TIME_STEPS])

	return offspring1, offspring2
}

mutate :: proc(population: ^[]Individual) {
	rng := rand.create(78)
	
	for individual in population {
		for i in 0..<5 {
			idx := rl.GetRandomValue(0, TIME_STEPS-1)
			rn := rand.float32(&rng)
			if rn < MUTATION_RATE {
				individual.genes[idx] = byte(rand.uint32(&rng) % 4)
			}
		}
	}
}

// SIMULATION/VISUALIZATION

createObstacles :: proc() -> [dynamic]Obstacle {
	obstacles: [dynamic]Obstacle
	numObstacles := 35
	
	for i in 0..<numObstacles {
		rc := rl.Rectangle{f32(rl.GetRandomValue(50, ScreenWidth-60)), f32(rl.GetRandomValue(60, ScreenHeight-60)), f32(rl.GetRandomValue(10,100)), f32(rl.GetRandomValue(10,100))}
		obstacle: Obstacle = {rc, rl.DARKBROWN}
		append(&obstacles, obstacle)
	}

	return obstacles
}

collide :: proc(individual: ^Individual, obstacle: ^rl.Rectangle) {
	player := individual.rec
	if rl.CheckCollisionRecs(player, obstacle^) {
		individual.collisions += 1
		player_center: rl.Vector2 = { player.x + player.width/2, player.y + player.height/2 }
		obstacle_center: rl.Vector2 = { obstacle.x + obstacle.width/2, obstacle.y + obstacle.height/2 }
		
		delta := player_center - obstacle_center
		
		hs1: rl.Vector2 = { player.width*.5, player.height*.5 }
		hs2: rl.Vector2 = { obstacle.width*.5, obstacle.height*.5 }
		
		minDistX := hs1.x + hs2.x - abs(delta.x)
		minDistY := hs1.y + hs2.y - abs(delta.y)
		
		if minDistX < minDistY {
			individual.rec.x += math.copy_sign_f32(minDistX, delta.x)
		} else {
			individual.rec.y += math.copy_sign_f32(minDistY, delta.y)
		}
	}	
} 

outOfBoundsCheck :: proc(player: ^rl.Rectangle) {
	if player.x <= 0 do player.x = 0
	if player.x >= f32(ScreenWidth) - player.width do player.x = f32(ScreenWidth) - player.width
	if player.y <= 0 do player.y = 0
	if player.y >= f32(ScreenHeight) - player.height do player.y = f32(ScreenHeight) - player.height
}

movePlayer :: proc(player: ^rl.Rectangle) {
	if rl.IsKeyDown(rl.KeyboardKey.W) do player.y -= 5
	if rl.IsKeyDown(rl.KeyboardKey.A) do player.x -= 5
	if rl.IsKeyDown(rl.KeyboardKey.S) do player.y += 5
	if rl.IsKeyDown(rl.KeyboardKey.D) do player.x += 5
}

moveIndividual :: proc(ind: ^Individual, currentTimeStep: int) {
		switch ind.genes[currentTimeStep] {
			case 0:
			ind.rec.y -= 10
			case 1:
			ind.rec.x -= 10
			case 2:
			ind.rec.y += 10
			case 3:
			ind.rec.x += 10
		}
}

targetReachedCheck :: proc(individual: ^Individual, currentTimeStep: int) {
	if rl.CheckCollisionRecs(individual.rec, TARGET) {
		individual.targetReached = currentTimeStep 
	}
}

main :: proc() {
	fmt.println("Hellope")
	
	rl.InitWindow(ScreenWidth, ScreenHeight, "Hellope")
	rl.SetTargetFPS(60)
	
	frameCount := 0
	
	position: rl.Vector2 = {0, 0}

	// create obstacles
	obstacles := createObstacles()
	
	// step #1: Create initial population
	population := createInitialPopulation()
	// fmt.println("sample genes")
	// fmt.println(population[0].genes)
	
	// step #2: Evaluate fitness of the population
	// for &individual in population {
	// 	for i := 0; i < TIME_STEPS; i += 1 {
	// 		moveIndividual(&individual, i)
	// 		outOfBoundsCheck(&individual.rec)
	// 		for &ob in obstacles {
	// 			collide(&individual, &(ob.rec))
	// 		}
	// 	}
	// 	individual.fitness = evaluateFitness(individual)
	// 	// fmt.println(individual.fitness)
	// }
	
	// player := rl.Rectangle{position.x, position.y, 20, 20}
	// collisions := 0
	
	// player := population[0]
	// geneIdx := 0
	// fmt.println(player.genes)
	// shouldMove := true
	
	currentTimeStep := 0
	currentGeneration := 0

	for !rl.WindowShouldClose() {
		frameCount += 1
		
		if currentGeneration < NUM_GENERATIONS {

			if  currentTimeStep >= TIME_STEPS - 1 {
				for &i in population {
					i.fitness = evaluateFitness(i)
				}
				// Step #3: Selection
				selectedIndividuals := selection(population)
				// Step #4: Crossover
				newPopulation := breedNewPopulation(selectedIndividuals)
				// Step #5: Mutation
				mutate(&newPopulation)
				
				// population = newPopulation
				for i := 0; i < len(newPopulation); i+=1 {
					population[i] = newPopulation[i]
				}
				currentTimeStep = 0
				currentGeneration += 1
			} else {
				for &individual in population {
					if individual.targetReached == 0 {
						moveIndividual(&individual, currentTimeStep)
						outOfBoundsCheck(&individual.rec)
						for &ob in obstacles {
							collide(&individual, &(ob.rec))
						}
						targetReachedCheck(&individual, currentTimeStep)
					}
				}
				currentTimeStep += 1
			}
			
			// if targetReachedCheck(&population) || currentTimeStep > TIME_STEPS {
			// 	currentGeneration += 1
			// 	currentTimeStep = 0
			// }
		}
	

		rl.BeginDrawing()
		rl.ClearBackground(rl.LIGHTGRAY)
		rl.DrawRectangleRec(TARGET, rl.GREEN)
		for individual in population {
			rl.DrawRectangleRec(individual.rec, rl.RED)
		}
		for ob in obstacles {
			rl.DrawRectangleRec(ob.rec, ob.color)
		}
		rl.DrawText(rl.TextFormat("Generation: %i", currentGeneration+1), 0, 0, 20, rl.BLACK)
		rl.EndDrawing()

		// if rl.IsKeyDown(rl.KeyboardKey.SPACE) && shouldMove {
		// 	shouldMove = false
		// 	moveIndividual(&player, geneIdx)
		// 	outOfBoundsCheck(&player.rec)
		// 	for &ob in obstacles {
		// 		collide(&player, &(ob.rec))
		// 	}
		// 	geneIdx += 1
		// 	if geneIdx >= len(player.genes) {
		// 		geneIdx = 0
		// 	}
		// }
		// if rl.IsKeyUp(rl.KeyboardKey.SPACE) && !shouldMove {
		// 	shouldMove = true
		// }
		
		

		// for i := 0; i < NUM_GENERATIONS; i+=1 {
		// 	// step #3: Selection
		// 	newPopulation := selection(population)

		// 	// step #4: Crossover

		// 	// step #5: Mutation
			
		// 	// step #6: Fitness evaluation
		// 	for j := 0; j < POPULATION_SIZE; j+=1 {
		// 		population[j].fitness = evaluateFitness(population[j])
		// 	}
		// 	// if reached the target break? or do we continue to potentialy get a more efficient route?

		// 	rl.BeginDrawing()
			
		// 	rl.ClearBackground(rl.RAYWHITE)
			
		// 	// step #7: draw simulation
		// 	rl.DrawRectangleV(position, 20, rl.MAROON)
			
		// 	for ob in obstacles {
		// 		rl.DrawRectangleRec(ob.rec, ob.color)
		// 	}

		// 	rl.EndDrawing()
		// }

		// movePlayer(&player)
		// outOfBoundsCheck(&player)
		// for &ob in obstacles {
		// 	collide(&player, &(ob.rec))
		// }
	}
	
	rl.CloseWindow()
}