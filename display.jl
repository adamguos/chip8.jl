import GLFW

# Create a window and its OpenGL context
window = GLFW.CreateWindow(256, 128, "GLFW.jl")

# Make the window's context current
GLFW.MakeContextCurrent(window)

# Loop until the user closes the window
while !GLFW.WindowShouldClose(window)
    # Render here

    # Swap front and back buffers
    GLFW.SwapBuffers(window)

    # Poll for and process events
    GLFW.PollEvents()
end