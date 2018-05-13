class Disk:
    def __init__(self):
        self.dev = None
        self.type = None
        self.transport = None
        self.port = None
        self.model = None
        self.serial = None
        self.size = None

    def __repr__(self):
        return '<Disk {} ({} {} on port {})>'.format(self.dev, self.transport, self.type, self.port)
