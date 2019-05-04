import socket
import numpy as np
from PIL import Image
from keras.models import Sequential, load_model
from keras.layers import Input, Dense, Conv2D, Activation, Flatten

MODEL_NAME = 'rcproamii.h5'

def initSocket():
    sock = socket.socket()
    
    host = 'localhost'
    port = 8084
    
    sock.bind((host, port))
    sock.listen(1)
    
    print('Waiting for accept...')

    conn, _ = sock.accept()

    print('Connection accepted')

    return conn

def makeModel():
    model = Sequential()
    model.add(Conv2D(32, (8, 8), strides=(4, 4), input_shape=(240,256,3)))
    model.add(Activation('relu'))
    model.add(Conv2D(64, (4, 4), strides=(2, 2)))
    model.add(Activation('relu'))
    model.add(Conv2D(64, (3, 3), strides=(1, 1)))
    model.add(Activation('relu'))
    model.add(Flatten())
    model.add(Dense(512))
    model.add(Activation('relu'))
    model.add(Dense(10, activation='sigmoid'))
    model.add(Dense(8, activation='linear'))
    model.compile(loss='mse', optimizer='adam', metrics=['mae'])
    return model

def displayImage(image):
    print('Display image')
    # img = Image.fromarray(image, 'RGB')
    # img.save('my.png')

def strToImg(str):
    # image 256 columns 240 rows, argb
    x = map(ord, str[11:])
    x = np.array(x,dtype=np.uint8)
    # remove alpha from array
    x = np.delete(x, np.arange(0, x.size, 4))
    x = x.reshape(240, 256, 3)
    x = np.expand_dims(x, axis=0)
    return x

def parseEnv(v):
    return int(v[0:2]), strToImg(v[2:])

def normalize(a):
    return map(lambda x: 49 if (x > 0) else 48, a)

def step(state):
    if (state == 0):            # Playing
        # print('Playing')
        return 0, False
    elif (state == 1):          # Dead
        print('Dead')
        return -10, False
    elif (state == 2):          # Paused
        print('Paused')
        return -5, False
    elif (state == 3):          # MovingForward
        print('MovingForward')
        return 1, False
    elif (state == 4):          # MovingBackward
        print('MovingBackward')
        return -2, False
    elif (state == 5):          # PickupLive
        print('PickupLive')
        return 5, False
    elif (state == 6):          # PickupLetter
        print('PickupLetter')
        return 5, False
    elif (state == 7):          # PickupStaff
        print('PickupStaff')
        return 3, False
    elif (state == 8):          # NextLevel
        print('NextLevel')
        return 10, False
    elif (state == 9):          # GameOver
        print('GameOver')
        return -50, False
    else:
        return10, False

y =           0.95
eps =         0.5
decayFactor = 0.999

# decay epsilon for consecutive episodes
# now do not know how to do this
# eps *= decay_factor
trainCountBeforeDecay = 0
# playingCount = 0
# pausedCount  = 0
def train(state, new_s, s):
    # print('---------')
    global eps
    global trainCountBeforeDecay
    # global playingCount
    # global pausedCount

    # if (state == 0):
    #     playingCount += 1
    # elif (state == 2):
    #     pausedCount += 1

    if np.random.random() < eps:
    # if (playingCount == 6):
        print('Random')
        # playingCount = 0
        a = np.random.randint(0, 2, 8)
    # elif (pausedCount == 6):
    #     pausedCount = 0
    #     a = np.array([0, 0, 0, 0, 0, 0, 0, 1])
    else:
        a = model.predict(s)[0]

    # a[7] = 0

    # a = model.predict(s)[0]

    if trainCountBeforeDecay == 100:
        eps *= decayFactor
        trainCountBeforeDecay = 0

    trainCountBeforeDecay += 1

    r, done = step(state)
    target_vec_new = model.predict(new_s)[0]
    target_vec = np.copy(a)
    # print(target_vec)
    for i in range(8):
        if (target_vec[i] > 0):
            target_vec[i] = r + y * target_vec_new[i]
    # print(target_vec)
    model.fit(s, target_vec.reshape(-1, 8), epochs=1, verbose=0)

    return a

try:
    model = load_model(MODEL_NAME)
    print("Model loaded")
except:
    model = makeModel()
conn  = initSocket()

# Array of 8 bytes length. Button names needs to substitute with 49 or 0
# 49 - ascii '1' and means true, other means false, 10 - ascii new line and means end of message
# ['A', 'up', 'left', 'B', 'select', 'right', 'down', 'start', 10]

# image length + state length
DATA_LENGTH = 245771 + 2
data = ''
s = []
firstIteration = True
while True:
    try:
        data += conn.recv(262144)
    except:
        print "Some error!"
        break

    # print(len(data))

    if (len(data) == 0):
        break

    if (len(data) == DATA_LENGTH):
        state, img = parseEnv(data)
        if (firstIteration):
            firstIteration = False
            a = np.array([0, 0, 0, 0, 0, 0, 0, 0])
        else:
            a = train(state, img, s)
        
        s = img

        a = normalize(a)
        a = np.append(a, 10)
        a = a.astype(np.uint8)
        a = a.tobytes()
        # print('Sending answer: {0}'.format(a))
        conn.send(a)
        data = ''

model.save(MODEL_NAME)
