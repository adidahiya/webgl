# WebGL Visualization

NUM_PARTICLES       = 300
PARTICLE_DEPTH      = 800       # Z-range for particle positions
PARTICLE_SPEED      = 4
PARTICLE_COLOR      = 0x333333
LINE_COLOR          = 0x666666
TEXT_COLOR          = 0x003366
FOG_COLOR           = 0xFFFFFF
FOG_DENSITY         = 0.0012    # How fast fog density increases
GRAPH_THRESHOLD     = 200       # How close vertices must be to have an edge
FLOAT_THRESHOLD     = 50        # How far a particle is allowed to travel
DISPLAY_TEXT        = "3D graph animation"

generateSprite = () ->
  w = 16
  h = 16
  canvas = document.createElement 'canvas'
  canvas.width = w
  canvas.height = h
  context = canvas.getContext '2d'

  gradient = context.createRadialGradient(w, h, 0, w, h, w)
  gradient.addColorStop(0, 'rgba(50, 50, 50, 1)')
  gradient.addColorStop(0.4, 'rgba(50, 50, 50, 1)')
  gradient.addColorStop(1, 'rgba(255, 255, 255, 1)')

  context.fillStyle = gradient
  context.fillRect(0, 0, w, h)
  return canvas

# TODO: move to utils module
# Returns a random integer between min and max
getRandomInt = (min, max) ->
  return Math.floor(Math.random() * (max - min + 1)) + min

particleMaterial = new THREE.ParticleBasicMaterial
  color: PARTICLE_COLOR
  size: 10
  blending: THREE.AdditiveBlending
lineMaterial = () ->
  return new THREE.LineBasicMaterial
    color: LINE_COLOR
    # Generate a random blue line color
    # color: getRandomInt(0x33, 0xCC) |
    #        getRandomInt(0x33, 0xCC) << 8 |
    #        getRandomInt(0x33, 0xCC) << 16
    linewidth: 1
textMaterial = new THREE.MeshBasicMaterial
  color: TEXT_COLOR

# Create a scene, camera, and renderer. Attach it to a canvas element.
setupScene = ($container) ->
  WIDTH       = $container.width()
  HEIGHT      = $container.height()
  VIEW_ANGLE  = 45
  ASPECT      = WIDTH / HEIGHT
  NEAR        = 0.1
  FAR         = 10000

  renderer = new THREE.WebGLRenderer
  # clearColor: 0xFFFFFF
  # clearAlpha: 1
    antialias: true
  camera  = new THREE.PerspectiveCamera(VIEW_ANGLE, ASPECT, NEAR, FAR)
  scene   = new THREE.Scene()

  scene.add camera
  camera.position.z = 1000 # Camera starts at (0,0,0) so pull it back
  camera.lookAt(new THREE.Vector3(0, 0, 0))
  renderer.setSize(WIDTH, HEIGHT)
  $container.append(renderer.domElement)

  return {
    renderer: renderer
    camera:   camera
    instance: scene
  }

# Generate a random position in the field of view
generatePosition = () ->
  x = Math.random() * 3200 - 1600
  y = Math.random() * 800 - 400
  z = Math.random() * PARTICLE_DEPTH - PARTICLE_DEPTH / 2
  return new THREE.Vector3(x, y, z)

# Generate a random velocity vector for a particle
generateVelocity = () ->
  xVel = Math.random() * PARTICLE_SPEED - PARTICLE_SPEED / 2
  yVel = Math.random() * PARTICLE_SPEED - PARTICLE_SPEED / 2
  zVel = Math.random() * 0.4 - 0.2
  return new THREE.Vector3(xVel, yVel, zVel)

createParticleSystem = () ->
  geometry = new THREE.Geometry()
  geometry.dynamic = true

  # Generate particles with random position & velocity
  for i in [1..NUM_PARTICLES]
    particle          = generatePosition()
    particle.initial  = particle.clone()
    particle.velocity = generateVelocity()
    particle.accel    = 0.95
    particle.name     = "#{i - 1}"
    geometry.vertices.push particle

  particles = new THREE.ParticleSystem(geometry, particleMaterial)
  particles.sortParticles = true
  return particles

# Initial O(n^2) calculation to assign connected vertices in graph
createGraph = (particles) ->
  graph = {}
  for v1 in particles.geometry.vertices
    subGraph = []
    for v2 in particles.geometry.vertices
      if Math.abs(v1.distanceTo(v2)) < GRAPH_THRESHOLD and not v1.equals(v2)
        index = parseInt(v2.name)
        subGraph.push index if index?
    if subGraph.length
      p = parseInt(v1.name)
      graph[p] = subGraph
  return graph

# For each connected subgraph, create a line geometry between each vertex
createGraphLines = (particles, graph) ->
  graphLines = []
  for rootIndex, connected of graph
    subGraph = new THREE.Geometry()
    # subGraph.dynamic = true
    root = particles.geometry.vertices[parseInt(rootIndex)]

    for i in connected
      particle = particles.geometry.vertices[i]
      subGraph.vertices.push particle if particle?
      subGraph.vertices.push root

    lines = new THREE.Line(subGraph, lineMaterial())
    lines.name = "graphLines"
    graphLines.push lines
  return graphLines

createText = () ->
  textGeometry = new THREE.TextGeometry DISPLAY_TEXT,
    size: 60
    height: 5
    curveSegments: 4
    font: "helvetiker"
    weight: "normal"
    style: "normal"
  # Center text at (0, 0, 0)
  textGeometry.computeBoundingBox()
  centerOffset = -0.5 * (textGeometry.boundingBox.max.x -
                          textGeometry.boundingBox.min.x)
  textMesh = new THREE.Mesh(textGeometry, textMaterial)
  textMesh.position.set(centerOffset, -30, 0)
  return textMesh

createFog = () ->
  fog = new THREE.FogExp2(FOG_COLOR, FOG_DENSITY)
  return fog

# Animation render loop
# TODO: optimizations
renderLoop = (scene) ->
  frame = 0
  update = () ->
    # Update positions
    for particle in scene.particles.geometry.vertices
      particle.addSelf(particle.velocity)

      # Don't let particle float too far
      if Math.abs(particle.y - particle.initial.y) > FLOAT_THRESHOLD
        particle.velocity.setY(-1 * particle.velocity.y)
      if Math.abs(particle.x - particle.initial.x) > FLOAT_THRESHOLD
        particle.velocity.setX(-1 * particle.velocity.x)
      if Math.abs(particle.z - particle.initial.z) > FLOAT_THRESHOLD
        particle.velocity.setZ(-1 * particle.velocity.z)

    # Tell the particle system that we've changed its vertices
    scene.particles.geometry.verticesNeedUpdate = true

    # Re-compute line geometry between vertices
    newGraphLines = createGraphLines(scene.particles, scene.graph)
    oldGraphLines = scene.instance.getChildByName("graphLines")
    # Remove all old graph lines
    while oldGraphLines
      scene.instance.remove oldGraphLines
      oldGraphLines = scene.instance.getChildByName("graphLines")

    scene.instance.add line for line in newGraphLines

    # ...and finally render
    scene.renderer.render(scene.instance, scene.camera)
    requestAnimationFrame(update)

  requestAnimationFrame(update)

init = () ->
  scene       = setupScene $('#sketch')
  particles   = createParticleSystem()
  graph       = createGraph(particles)
  graphLines  = createGraphLines(particles, graph)
  sceneText   = createText()

  scene.instance.add particles
  scene.instance.add subGraph for subGraph in graphLines
  scene.instance.fog = createFog()
  scene.instance.add sceneText

  scene.graph = graph
  scene.particles = particles
  renderLoop(scene)

init()
