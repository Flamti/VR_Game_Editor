def can_build(env, platform):
    # Прибор нужен только там, где есть RenderingDevice (Vulkan).
    return env.get("vulkan", True)


def configure(env):
    pass
