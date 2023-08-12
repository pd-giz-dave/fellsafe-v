module contours

/*
def _test(src, size, proximity, black, inverted, blur, mode, logger, params=None):
    """ ************** TEST **************** """

    if logger.depth() > 1:
        logger.push(context='contours/_test')
    else:
        logger.push(context='_test')
    logger.log('')
    logger.log("Detecting contours")
    shrunk = canvas.prepare(src, size, logger)
    if shrunk is None:
        logger.pop()
        return None
    logger.log("Proximity={}, blur={}".format(proximity, blur))
    params = set_params(src, proximity, black, inverted, blur, mode, params)
    # do the actual detection
    params = find_contours(shrunk, params, logger=logger)
    logger.pop()
    return params


if __name__ == "__main__":
    #src = "targets.jpg"
    #src = "/home/dave/blob-extractor/test/data/checker.png"
    #src = "/home/dave/blob-extractor/test/data/diffract.png"
    #src = "/home/dave/blob-extractor/test/data/dummy.png"
    #src = "/home/dave/blob-extractor/test/data/labyrinth.png"
    #src = "/home/dave/blob-extractor/test/data/lines.png"
    #src = "/home/dave/blob-extractor/test/data/simple.png"
    #src = "/home/dave/precious/fellsafe/fellsafe-image/source/kilo-codes/test-alt-bits.png"
    src = '/home/dave/precious/fellsafe/fellsafe-image/media/kilo-codes/kilo-codes-distant-150-257-263-380-436-647-688-710-777.jpg'
    #proximity = const.PROXIMITY_CLOSE
    proximity = const.PROXIMITY_FAR

    # region test shape...
    # shape = [[0,0,0,0,0,0,0,0,0,0],
    #          [0,0,0,0,0,0,0,0,0,0],
    #          [0,1,1,0,0,0,0,1,1,0],
    #          [0,1,0,1,1,1,1,0,1,0],
    #          [0,0,1,1,1,1,1,0,0,0],
    #          [0,0,1,1,1,1,1,0,0,0],
    #          [0,0,1,1,1,1,1,0,0,0],
    #          [0,0,1,1,1,1,0,1,0,0],
    #          [0,0,0,0,0,0,1,1,0,0],
    #          [0,0,0,0,0,0,0,0,0,0]]
    # image = np.zeros((len(shape), len(shape[0])), np.uint8)
    # for y, row in enumerate(shape):
    #     for x, pixel in enumerate(row):
    #         image[y, x] = pixel * 255
    # blobs, buffer, labels = find_blobs(image)
    # endregion

    logger = utils.Logger('contours.log', 'contours/{}'.format(utils.image_folder(src)))

    _test(src, size=const.VIDEO_2K, proximity=proximity, black=const.BLACK_LEVEL[proximity],
          inverted=True, blur=const.BLUR_KERNEL_SIZE, mode=const.RADIUS_MODE_MEAN, logger=logger)
*/
